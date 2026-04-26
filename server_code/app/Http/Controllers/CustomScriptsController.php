<?php

namespace App\Http\Controllers;

use App\Models\CustomScript;
use App\Models\Helper\ControllerHelper;
use App\Models\Helper\Response;
use App\Models\Helper\Utils;
use App\Models\Helper\Validation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Config;

class CustomScriptsController extends ControllerHelper
{
    public function all(Request $request)
    {
        try {
            $lang = $request->header('language');

            if ($can = Utils::userCan($this->user, 'header_link.view')) {
                return $can;
            }

            $query = CustomScript::query();

            $query = $query->orderBy('custom_scripts.' . $request->orderby, $request->type);

            if ($request->q) {
                $query = $query->where('custom_scripts.route_pattern', 'LIKE', "%{$request->q}%");
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

            if ($can = Utils::userCan($this->user, 'header_link.view')) {
                return $can;
            }

            $query = CustomScript::query();



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

            $validate = Validation::customScript($request);
            if ($validate) {
                return response()->json($validate);
            }

            if ($id) {
                if ($can = Utils::userCan($this->user, 'header_link.edit')) {
                    return $can;
                }

                $filtered = array_filter($request->all(), function ($element) {
                    return '' !== trim($element);
                });

                $filtered['header_script'] = $request->header_script;
                $filtered['body_script'] = $request->body_script;

                $filtered['header_script_code'] = $request->header_script_code;
                $filtered['body_script_code'] = $request->body_script_code;

                CustomScript::where('id', $id)->update($filtered);

            } else {
                if ($can = Utils::userCan($this->user, 'header_link.create')) {
                    return $can;
                }


                $brand = CustomScript::create($request->all());
                $id = $brand->id;
            }

            $query = CustomScript::query();


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


            if($can = Utils::userCan($this->user, 'header_link.delete')){
                return $can;
            }

            $ids =  explode(",", $id);

            foreach ($ids as $i){



                $page = CustomScript::find($i);

                if (is_null($page)){
                    return response()->json(Validation::noDataLang($lang));
                }


                $page->delete();




            }

            return response()->json(new Response($request->token, true));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }
}
