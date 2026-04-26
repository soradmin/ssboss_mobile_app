<?php

namespace App\Http\Controllers;

use App\Models\Helper\Response;
use App\Models\Helper\Validation;
use App\Models\ProductImageAttribute;
use Illuminate\Http\Request;

class ProductImageAttributesController extends Controller
{

    public function action(Request $request)
    {
        try {

            $lang = $request->header('language');

            $validate = Validation::imageAttribute($request);
            if ($validate) {
                return response()->json($validate);
            }


            $existingAttributes = ProductImageAttribute::where('product_image_id', $request->product_image_id)
                ->get();

            $existingIds = [];
            foreach ($existingAttributes as $ea){

                $existingIds[$ea->id] = $ea;
            }


            foreach ($request->values as $attr){

                if(key_exists($attr, $existingIds)){

                    unset($existingIds[$attr]);

                } else {

                    ProductImageAttribute::create([
                        'product_image_id' => $request->product_image_id ,
                        'product_id' => $request->product_id ,
                        'attribute_value_id' => $attr
                    ]);

                }
            }

            foreach ($existingIds as $key => $value){

                ProductImageAttribute::where('id', $value->id)->delete();

            }


            return response()->json(new Response($request->token, true));


        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage(), "images_attribute"));
        }
    }
}
