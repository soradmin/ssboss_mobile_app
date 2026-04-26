<?php

namespace App\Http\Controllers;

use App\Models\GuestUser;
use App\Models\Helper\ControllerHelper;
use App\Models\Helper\Response;
use App\Models\Helper\Validation;
use App\Models\Setting;
use App\Models\UpdatedInventory;
use App\Models\User;
use App\Models\Cart;
use App\Models\UserAddress;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Config;

class CartsController extends ControllerHelper
{
    public function byUser(Request $request)
    {
        try {
            $lang = $request->header('language');

            $query = Cart::query();

            if ($lang) {

                $query = $query->with(['updated_inventory.inventory_attributes.attribute_value.attribute' =>
                    function ($query) use ($lang) {
                        $query->leftJoin('attribute_langs as al', function ($join) use ($lang) {
                            $join->on('al.attribute_id', '=', 'attributes.id');
                            $join->where('al.lang', $lang);
                        })
                            ->select('attributes.*', 'al.title');
                    }]);

                $query = $query->with(['updated_inventory.inventory_attributes.attribute_value' =>
                    function ($query) use ($lang) {

                        $query->leftJoin('attribute_value_langs as avl',
                            function ($join) use ($lang) {
                                $join->on('attribute_values.id', '=', 'avl.attribute_value_id');
                                $join->where('avl.lang', $lang);
                            })
                            ->select('attribute_values.*', 'avl.title');
                    }]);

                $query = $query->with(['flash_product' => function ($query) use ($lang) {
                    $query->with(['product_images' => function($query){
                        $query->with(['attributes' => function($query){}]);
                    }]);

                    $query->with(['shipping_rule' => function($query){
                        $query->with(['shipping_places' => function($query){
                            $query->with(['shipping_rule' => function($query){
                            }]);
                        }]);
                    }]);

                    $query->leftJoin('product_langs as pl', function ($join) use ($lang) {

                        $join->on('pl.product_id', '=', 'products.id');
                        $join->where('pl.lang', $lang);

                    })->with(['bundle_deal' => function ($query) use ($lang) {

                            $query->leftJoin('bundle_deal_langs as pcl', function ($join) use ($lang) {
                                $join->on('pcl.bundle_deal_id', '=', 'bundle_deals.id');
                                $join->where('pcl.lang', $lang);
                            })
                                ->select('bundle_deals.*', 'pcl.title');

                        }])
                        ->select('products.id', 'products.bundle_deal_id', 'pl.title', 'products.slug',
                            'products.selling', 'products.offered', 'products.tax_rule_id',
                            'products.image', 'products.review_count', 'products.rating', 'products.shipping_rule_id',
                            'flash_sale_products.price',
                            'flash_sales.end_time');
                }]);

            } else {

                $query = $query->with(['flash_product' => function ($query) use ($lang) {
                    $query->with(['product_images' => function($query){
                        $query->with(['attributes' => function($query){}]);
                    }]);

                    $query->with(['shipping_rule' => function($query){
                        $query->with(['shipping_places' => function($query){
                            $query->with(['shipping_rule' => function($query){}]);
                        }]);
                    }]);
                }]);

                $query = $query->with(['updated_inventory' => function ($query) {
                    $query->with(['inventory_attributes' => function ($query){
                        $query->with(['attribute_value' => function ($query){
                            $query->with(['attribute']);
                        }]);
                    }]);
                }]);
            }


            if($this->user && $request->admin_id){

                $query = $query->where('admin_id', $this->user->id);

            } else if ($request->user('user')) {

                $query = $query->where('user_id', $request->user('user')->id);

            } else if($request->user_token){

                $query = $query->where('user_token', $request->user_token);

            } else {

                return response()->json(Validation::errorLang($lang));
            }

            $query = $query->with('shipping_place.shipping_rule');
            $query = $query->select('id', 'product_id', 'user_id', 'inventory_id', 'quantity',
                    'selected', 'shipping_place_id', 'shipping_type');
            $data = $query->get();

            return response()->json(new Response($request->token, $data));


        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function buyNow(Request $request)
    {
        try {
            $lang = $request->header('language');

            $validate = Validation::cart($request);
            if ($validate) {
                return response()->json($validate);
            }

            $q = Cart::query();


            if($this->user){

                $q = $q->where('admin_id', $this->user->id);

            } else if ($request->user('user')) {

                $q = $q->where('user_id', $request->user('user')->id);

            } else if($request->user_token){

                $q = $q->where('user_token', $request->user_token);

            }  else {

                return response()->json(Validation::errorLang($lang));

            }


            $q = $q->where('product_id', $request->product_id);
            $q = $q->where('inventory_id', $request->inventory_id);
            $existingCart = $q->first();

            if ($existingCart) {
                $inventory = UpdatedInventory::find($request->inventory_id);

                if ($request->quantity > $inventory->quantity) {
                    return response()->json(Validation::error($request->token,
                        __('lang.quantity_exceeds', [], $lang)
                    ));
                }
                Cart::where('id', $existingCart->id)->update([
                    'quantity' => $request->quantity,
                    'selected' => Config::get('constants.status.PUBLIC')
                ]);

                $existingCart->quantity = $request->quantity;
                $cart = $existingCart;

            } else {


                if($this->user){

                    $request['admin_id'] =$this->user->id;

                } else if ($request->user('user')) {

                    $request['user_id'] = $request->user('user')->id;

                } else if($request->user_token){

                    $guestUser = GuestUser::where('user_token', $request->user_token)
                        ->first();

                    if(!$guestUser){
                        GuestUser::create([
                            "user_token" => $request->user_token
                        ]);
                    }
                }

                $cart = Cart::create($request->all());
            }

            Cart::where('selected', Config::get('constants.status.PUBLIC'))
                ->where('id', '!=', $cart->id)
                ->update(['selected' => Config::get('constants.status.PRIVATE')]);

            return response()->json(new Response($request->token, $cart));


        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function action(Request $request)
    {
        try {

            $lang = $request->header('language');

            $validate = Validation::cart($request);
            if ($validate) {
                return response()->json($validate);
            }

            $q = Cart::query();


            if($this->user){

                $q = $q->where('admin_id', $this->user->id);

            } else if ($request->user('user')) {

                $q = $q->where('user_id', $request->user('user')->id);

            } else if($request->user_token){

                $setting = Setting::select('guest_checkout')->first();
                if(!$setting->guest_checkout){
                    return response()->json(Validation::unauthorized());
                }

                $q = $q->where('user_token', $request->user_token);

            }else {

                return response()->json(Validation::errorLang($lang));
            }


            $q = $q->where('product_id', $request->product_id);
            $q = $q->where('inventory_id', $request->inventory_id);
            $existingCart = $q->first();

            if ($existingCart) {

                $inventory = UpdatedInventory::find($request->inventory_id);

                if ($existingCart->quantity + $request->quantity > $inventory->quantity) {
                    return response()->json(Validation::error($request->token,
                        __('lang.quantity_exceeds', [], $lang)
                    ));
                }
                Cart::where('id', $existingCart->id)->update([
                    'quantity' => $existingCart->quantity + $request->quantity
                ]);

                $existingCart->quantity = $existingCart->quantity + $request->quantity;
                $cart = $existingCart;

            } else {


                if($this->user){

                    $request['admin_id'] = $this->user->id;

                } else if ($request->user('user')) {

                    $request['user_id'] = $request->user('user')->id;

                } else if($request->user_token){

                    $guestUser = GuestUser::where('user_token', $request->user_token)
                        ->first();

                    if(!$guestUser){
                        GuestUser::create([
                            "user_token" => $request->user_token
                        ]);
                    }
                }

                $cart = Cart::create($request->all());
            }

            return response()->json(new Response($request->token, $cart));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function updateShipping(Request $request)
    {
        try {
            $lang = $request->header('language');

            $validate = Validation::shippingCart($request);

            if ($validate){
                return response()->json($validate);
            }

            $cartArrz = [];

            $cartIds = [];

            foreach ($request->cart as $i) {
                array_push($cartIds, $i['cart']);

                if($i['shipping_place']) {
                    $v['shipping_place_id'] = $i['shipping_place']['id'];
                } else {
                    $v['shipping_place_id'] = null;
                }

                $v['shipping_type'] = $i['shipping_type'];
                $v['cart'] = $i['cart'];
                array_push($cartArrz, $v);
            }

            $cartError = [];
            $carts = Cart::whereIn('id', $cartIds)
                ->where('selected', Config::get('constants.status.PUBLIC'))
                ->with('product')
                ->with('updated_inventory')
                ->get();

            foreach ($carts as $c) {
                $productErr = [];
                $error = false;

                if ($c->product->status != Config::get('constants.status.PUBLIC')) {
                    array_push($productErr,
                        $c->product->title . __('lang.uncheck_cart', [], $lang));
                    $error = true;
                }
                if ((int)$c->updated_inventory->quantity < 1) {
                    array_push($productErr,
                        $c->product->title . __('lang.stock_out', [], $lang));
                    $error = true;
                }
                if ($error) {
                    $cartError[$c->id] = $productErr;
                }
            }

            if (count($cartError) > 0) {
                return response()->json(Validation::error($request->token, $cartError, 'product'));
            }



            if($request->user('user') && $request->selected_address) {
                User::where('id', $request->user('user')->id)
                    ->update(['default_address' => $request->selected_address]);

            } else if($request->user_token && $request->selected_address){

                $userAddress = UserAddress::where('id', $request->selected_address)
                    ->first();


                GuestUser::where('user_token', $request->user_token)
                    ->update([
                        'name' => $userAddress->name,
                        'default_address' => $request->selected_address
                    ]);
            }


            \DB::transaction(function () use ($cartArrz) {
                foreach ($cartArrz as $key => $value) {
                    Cart::where('id', '=', $value['cart'])->update([
                            'shipping_place_id' => $value['shipping_place_id'],
                            'shipping_type' => $value['shipping_type']
                        ]
                    );
                }
            });



            $query = Cart::query();
            $query = $query->with('flash_product.shipping_rule.shipping_places');
            $query = $query->with('updated_inventory.inventory_attributes.attribute_value.attribute');
            $query = $query->with('shipping_place.shipping_rule');
            $query = $query->select('id', 'product_id', 'user_id', 'inventory_id', 'quantity',
                'selected', 'shipping_place_id', 'shipping_type');


            if($this->user){

                $query = $query->where('admin_id', $this->user->id);

            } else if ($request->user('user')) {

                $query = $query->where('user_id', $request->user('user')->id);

            } else if($request->user_token){

                $query = $query->where('user_token', $request->user_token);

            } else {

                return response()->json(Validation::errorLang($lang));
            }



            $data = $query->get();


            return response()->json(new Response($request->token, $data));


        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function changeSelected(Request $request)
    {
        try {

            Cart::whereIn('id', $request->checked)
                ->update(['selected' => 1]);

            Cart::whereIn('id', $request->unchecked)
                ->update(['selected' => 2]);

            return response()->json(new Response('', true));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }



    public function delete(Request $request, $id)
    {
        try {

            $lang = $request->header('language');
            $cart = Cart::find($id);

            if (is_null($cart)){
                return response()->json(Validation::nothingFoundLang($lang));
            }


            if ($cart->delete()) {
                return response()->json(new Response($request->token, $cart));
            }

            return response()->json(Validation::error($request->token, null, 'form', $lang));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }

}
