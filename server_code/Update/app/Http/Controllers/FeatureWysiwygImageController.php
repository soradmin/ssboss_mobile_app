<?php

namespace App\Http\Controllers;

use App\Models\FeatureWysiwygImage;
use App\Models\Helper\ControllerHelper;
use App\Models\Helper\FileHelper;
use App\Models\Helper\Response;
use App\Models\Helper\Utils;
use App\Models\Helper\Validation;
use App\Models\SiteFeature;
use Illuminate\Http\Request;

class FeatureWysiwygImageController extends ControllerHelper
{
    public function upload(Request $request)
    {
        try{

            if($request['item_id']){
                if($can = Utils::userCan($this->user, 'home_slider.edit')){
                    return $can;
                }
            }else{
                if($can = Utils::userCan($this->user, 'home_slider.create')){
                    return $can;
                }
            }

            $validate = Validation::page_wysiwyg_image($request);
            if($validate){
                return response()->json($validate);
            }

            $imageInfo = FileHelper::uploadImage($request['photo'], 'wysiwyg-image-feature', false);
            $url = FileHelper::imageFullUrl($imageInfo['name']);

            if(!is_null($request['site_feature'])){
                $page = json_decode($request['site_feature'], true);


                $page['detail'] = $page['detail'] . "<img src='" . $url . "'>";


                $filtered = array_filter($page, function ($element) {
                    return !is_array($element) && '' !== trim($element);
                });

                $page = SiteFeature::create($filtered);
                $request['site_feature_id'] = $page['id'];

            }else if($request['item_id']){
                $page['detail'] = $request['detail'] . "<img src='" . $url . "'>";
                SiteFeature::where('id', $request['site_feature_id'] )->update($page);
            }

            $request['image'] = $imageInfo['name'];

            $pageWysiwygImage = FeatureWysiwygImage::create($request->all());
            $pageWysiwygImage['url'] =  $url;

            return response()->json(new Response($request->token, $pageWysiwygImage));


        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }

    }

    public function delete(Request $request, $image_name)
    {
        try{
            if($can = Utils::userCan($this->user, 'home_slider.edit')){
                return $can;
            }

            FileHelper::deleteFile($image_name);

            $pageWysiwygImage = FeatureWysiwygImage::where('image', $image_name)->get()->first();

            if ($pageWysiwygImage){


                FeatureWysiwygImage::where('image', $image_name)->delete();
            }

            return response()->json(new Response($request->token, $pageWysiwygImage));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }
}
