<?php

namespace App\Http\Controllers;

use App\Models\Helper\ControllerHelper;
use App\Models\Helper\FileHelper;
use App\Models\Helper\Response;
use App\Models\Helper\Utils;
use App\Models\Helper\Validation;
use App\Models\PosOrder;
use App\Models\PosSetting;
use App\Models\PosSettingLang;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Config;

class PosSettingsController extends ControllerHelper
{




    public function find(Request $request)
    {
        try {

            $lang = $request->header('language');

            if ($can = Utils::userCan($this->user, 'pos_setting.view')) {
                return $can;
            }

            $query = PosSetting::query();
            if ($lang) {
                $query = $query->leftJoin('pos_setting_langs as cl', function ($join) use ($lang) {
                    $join->on('cl.pos_setting_id', '=', 'pos_settings.id');
                    $join->where('cl.lang', $lang);
                });
                $query = $query->select('pos_settings.*', 'cl.address', 'cl.header_text', 'cl.footer_text');
            }

            $category = $query->where('admin_id', $this->user->id)->first();

            if ($this->isVendor && $isOwner = Utils::isDataOwner($this->user, $category)) {
                return $isOwner;
            }


            return response()->json(new Response($request->token, $category));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function action(Request $request)
    {
        try {
            $lang = $request->header('language');
            $existing = PosSetting::where('admin_id', $this->user->id)->first();

            if ($existing) {
                if ($can = Utils::userCan($this->user, 'pos_setting.edit')) {
                    return $can;
                }


                if ($this->isVendor && $isOwner = Utils::isDataOwner($this->user, $existing)) {
                    return $isOwner;
                }


                $request['created_at'] = null;
                $request['updated_at'] = null;


                if ($lang) {
                    [$langData, $mainData] = Utils::seperateLangData($request->all(), ['address', 'header_text', 'footer_text']);
                    PosSetting::where('id', $existing->id)->update($mainData);
                    $existingLang = PosSettingLang::where('pos_setting_id', $existing->id)
                        ->where('lang', $lang)
                        ->first();

                    if (!$existingLang) {
                        $langData['pos_setting_id'] = $existing->id;
                        $langData['lang'] = $lang;
                        PosSettingLang::create($langData);

                    } else {
                        PosSettingLang::where('id', $existingLang->id)->update($langData);
                    }
                } else {
                    PosSetting::where('id', $existing->id)->update($request->all());
                }

            } else {
                if ($can = Utils::userCan($this->user, 'pos_setting.create')) {
                    return $can;
                }


                $request['admin_id'] = $request->user()->id;

                if ($lang) {
                    [$langData, $mainData] = Utils::seperateLangData($request->all(),
                        ['address', 'header_text', 'footer_text']);
                    $category = PosSetting::create($mainData);

                    $langData['pos_setting_id'] = $category->id;
                    $langData['lang'] = $lang;
                    PosSettingLang::create($langData);

                } else {
                    PosSetting::create($request->all());
                }
            }

            $query = PosSetting::query();
            if ($lang) {
                $query = $query->leftJoin('pos_setting_langs as cl', function ($join) use ($lang) {
                    $join->on('cl.pos_setting_id', '=', 'pos_settings.id');
                    $join->where('cl.lang', $lang);
                });
                $query = $query->select('pos_settings.*', 'cl.address', 'cl.header_text', 'cl.footer_text');
            }

            $category = $query->where('admin_id', $this->user->id)->first();

            return response()->json(new Response($request->token, $category));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function delete(Request $request)
    {
        try {

            $lang = $request->header('language');

            if ($can = Utils::userCan($this->user, 'pos_setting.delete')) {
                return $can;
            }

                $category = PosSetting::where('admin_id', $this->user->id)->first();

                if ($this->isVendor && $isOwner = Utils::isDataOwner($this->user, $category)) {
                    return $isOwner;
                }

                if (is_null($category)){
                    return response()->json(Validation::nothingFoundLang($lang));
                }

                PosSettingLang::where('pos_setting_id', $category->id)->delete();

                if ($category->delete()) {
                    FileHelper::deleteFile($category->image);
                }


            return response()->json(new Response($request->token, true));

            //return response()->json(Validation::errorTokenLang($request->token, $lang));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function upload(Request $request)
    {
        try {
            $lang = $request->header('language');

            $validate = Validation::image($request);
            if ($validate) {
                return response()->json($validate);
            }

            $image_info = FileHelper::uploadImage($request['photo'], 'pos_setting');
            $request['image'] = $image_info['name'];

            $existing = PosSetting::where('admin_id', $this->user->id)->first();



            if (is_null($existing)) {
                if ($can = Utils::userCan($this->user, 'pos_setting.create')) {
                    return $can;
                }

                $request['admin_id'] = $request->user()->id;

                $category = PosSetting::create($request->all());
                $id = $category->id;

            } else {
                if ($can = Utils::userCan($this->user, 'pos_setting.edit')) {
                    return $can;
                }
                if ($this->isVendor && $isOwner = Utils::isDataOwner($this->user, $existing)) {
                    return $isOwner;
                }

                $category_image = $existing->image;
                if ($existing->update($request->all())) {
                    FileHelper::deleteFile($category_image);
                }
            }


            $query = PosSetting::query();
            if ($lang) {
                $query = $query->leftJoin('pos_setting_langs as cl', function ($join) use ($lang) {
                    $join->on('cl.pos_setting_id', '=', 'pos_settings.id');
                    $join->where('cl.lang', $lang);
                });
                $query = $query->select('pos_settings.*', 'cl.address', 'cl.header_text', 'cl.footer_text');
            }

            $category = $query->where('admin_id', $this->user->id)->first();

            return response()->json(new Response($request->token, $category));


        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }

    }
}
