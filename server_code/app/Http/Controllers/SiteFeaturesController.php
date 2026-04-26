<?php

namespace App\Http\Controllers;

use App\Models\FeatureWysiwygImage;
use App\Models\Helper\ControllerHelper;
use App\Models\Helper\FileHelper;
use App\Models\Helper\Response;
use App\Models\Helper\Utils;
use App\Models\Helper\Validation;
use App\Models\SiteFeature;
use App\Models\SiteFeatureLang;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Config;

class SiteFeaturesController extends ControllerHelper
{
    public function all(Request $request)
    {
        try {
            $lang = $request->header('language');

            if ($can = Utils::userCan($this->user, 'home_slider.view')) {
                return $can;
            }

            $query = SiteFeature::query();

            $query = $query->orderBy('site_features.' . $request->orderby, $request->type);

            if ($lang) {
                $query = $query->leftJoin('site_feature_langs as trl', function ($join) use ($lang) {
                    $join->on('trl.site_feature_id', '=', 'site_features.id');
                    $join->where('trl.lang', $lang);
                });
                $query = $query->select('site_features.*', 'trl.detail');


                if ($request->q) {
                    $query = $query->where('trl.detail', 'LIKE', "%{$request->q}%");
                }
            }else {

                if ($request->q) {
                    $query = $query->where('site_features.detail', 'LIKE', "%{$request->q}%");
                }
            }


            $data = $query->paginate(Config::get('constants.api.PAGINATION'));

            foreach ($data as $item) {
                $item['created'] = Utils::formatDate($item->created_at);
            }

            return response()->json(new Response($request->token, $data));


        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function find(Request $request, $id)
    {

        try {

            $lang = $request->header('language');

            if ($can = Utils::userCan($this->user, 'home_slider.view')) {
                return $can;
            }

            $query = SiteFeature::query();

            if ($lang) {
                $query = $query->leftJoin('site_feature_langs as cl', function ($join) use ($lang) {
                    $join->on('cl.site_feature_id', '=', 'site_features.id');
                    $join->where('cl.lang', $lang);
                });
                $query = $query->select('site_features.*', 'cl.detail');
            }
            $banner = $query->find($id);

            if (is_null($banner)) {
                return response()->json(Validation::noDataLang($lang));
            }

            return response()->json(new Response($request->token, $banner));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function action(Request $request, $id = null)
    {
        try {

            $lang = $request->header('language');

            $validate = Validation::siteFeature($request);
            if ($validate) {
                return response()->json($validate);
            }

            if ($id) {
                if ($can = Utils::userCan($this->user, 'home_slider.edit')) {
                    return $can;
                }

                $filtered = array_filter($request->all(), function ($element) {
                    return '' !== trim($element);
                });


                if ($lang) {
                    [$langData, $mainData] = Utils::seperateLangData($filtered, ['detail']);



                    SiteFeature::where('id', $id)->update($mainData);

                    $existingLang = SiteFeatureLang::where('site_feature_id', $id)
                        ->where('lang', $lang)->first();


                    if (!$existingLang) {

                        $langData['site_feature_id'] = $id;
                        $langData['lang'] = $lang;


                        SiteFeatureLang::create($langData);

                    } else {
                        SiteFeatureLang::where('id', $existingLang->id)->update($langData);
                    }
                } else {
                    SiteFeature::where('id', $id)->update($filtered);
                }

            } else {
                if ($can = Utils::userCan($this->user, 'home_slider.create')) {
                    return $can;
                }

                $request['image'] = Config::get('constants.media.DEFAULT_IMAGE');


                if ($lang) {
                    [$langData, $mainData] = Utils::seperateLangData($request->all(), ['title']);
                    $brand = SiteFeature::create($mainData);

                    $langData['brand_id'] = $brand->id;
                    $langData['lang'] = $lang;
                    SiteFeatureLang::create($langData);
                    $id = $brand->id;

                } else {
                    $brand = SiteFeature::create($request->all());
                    $id = $brand->id;
                }
            }

            $query = SiteFeature::query();
            if ($lang) {
                $query = $query->leftJoin('site_feature_langs as b', function ($join) use ($lang) {
                    $join->on('b.site_feature_id', '=', 'site_features.id');
                    $join->where('b.lang', $lang);
                });
                $query = $query->select('site_features.*', 'b.detail');
            }
            $brand = $query->find($id);


            return response()->json(new Response($request->token, $brand));


        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function delete(Request $request, $id)
    {
        try{

            $lang = $request->header('language');


            if($can = Utils::userCan($this->user, 'home_slider.delete')){
                return $can;
            }

            $ids =  explode(",", $id);

            foreach ($ids as $i){



                $page = SiteFeature::find($i);

                if (is_null($page)){
                    return response()->json(Validation::noDataLang($lang));
                }



                $descriptionImages = FeatureWysiwygImage::where(['site_feature_id' => $i])->get();
                foreach ($descriptionImages as $di){
                    $di->delete();
                    FileHelper::deleteFile($di->image);
                }

                SiteFeatureLang::where('site_feature_id', $i)->delete();

                if ($page->delete()){
                    FileHelper::deleteFile($page->image);
                }




            }

            return response()->json(new Response($request->token, true));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }



    public function upload(Request $request, $id = null)
    {
        try {
            $lang = $request->header('language');

            $image_info = FileHelper::uploadImage($request['photo'], 'site-feature');
            $request['image'] = $image_info['name'];

            $banner = $id ? SiteFeature::find($id) : null;

            if (is_null($banner)) {
                $banner = SiteFeature::create($request->all());
                $id = $banner->id;

            } else {
                $image = $banner->image;
                if ($banner->update($request->all())) {
                    FileHelper::deleteFile($image);
                }
            }

            $query = SiteFeature::query();

            if ($lang) {
                $query = $query->leftJoin('site_setting_langs as cl', function ($join) use ($lang) {
                    $join->on('cl.site_setting_id', '=', 'site_settings.id');
                    $join->where('cl.lang', $lang);
                });
                $query = $query->select('site_settings.*', 'cl.detail');
            }
            $banner = $query->find($id);

            return response()->json(new Response($request->token, $banner));


        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }
}
