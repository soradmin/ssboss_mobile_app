<?php

namespace App\Http\Controllers;

use App\Models\Cancellation;
use App\Models\Cart;
use App\Models\Helper\ControllerHelper;
use App\Models\Helper\Response;
use App\Models\Helper\Utils;
use App\Models\Helper\Validation;
use App\Models\Order;
use App\Models\OrderedProduct;
use App\Models\PosOrder;
use App\Models\Setting;
use App\Models\UpdatedInventory;
use App\Models\Voucher;
use Carbon\Carbon;
use Carbon\Traits\Creator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Config;

class PosOrdersController extends ControllerHelper
{
    public function all(Request $request)
    {
        try {
            $lang = $request->header('language');

            if ($can = Utils::userCan($this->user, 'pos.view')) {
                return $can;
            }

            $query = PosOrder::query();

            if ($this->isVendor) {
                $query = $query->where('admin_id', $this->user->id);
            }

            if ($lang) {
                $query = $query->with(['order' => function ($query) use ($lang) {
                    $query->with(['ordered_products' => function ($query) use ($lang){
                        $query->with(['product'=> function ($query) use ($lang) {

                            $query->leftJoin('product_langs as pl', function ($join) use ($lang) {
                                $join->on('pl.product_id', '=', 'products.id');
                                $join->where('pl.lang', $lang);
                            })
                                ->select(['products.id', 'products.slug', 'pl.badge', 'pl.title',
                                    'products.selling', 'products.offered',
                                    'products.image', 'products.review_count', 'products.rating']);

                        }]);
                    }]);

                    $query->with(['pos_order' => function ($query){
                        $query->with(['admin']);
                    }]);

                    $query->with(['user']);
                }]);

            }else{
                $query = $query->with(['order' => function ($query) {
                    $query->with(['ordered_products' => function ($query){
                        $query->with(['product']);
                    }]);

                    $query->with(['pos_order' => function ($query){
                        $query->with(['admin']);
                    }]);

                    $query->with(['user']);
                }]);
            }




            $query = $query->orderBy($request->orderby, $request->type);

            $data = $query->paginate(Config::get('constants.api.PAGINATION'));

            foreach ($data as $item) {

                $item['order']['calculated'] = Utils::calcPrice($item->order);

                $item['order']['created'] = Utils::formatDate($item->order->created_at);
            }

            return response()->json(new Response($request->token, $data));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }



    public function action(Request $request)
    {
        try {
            $lang = $request->header('language');

            $cartQuery = Cart::with('product_inner.admin');


            $cartQuery = $cartQuery->where('admin_id', $this->user->id);

            $existingCart = $cartQuery->with('shipping_place.shipping_rule')
                ->where('selected', Config::get('constants.status.PUBLIC'))
                ->with('updated_inventory')
                ->get();

            $totalPriceWithoutShipping = 0;
            foreach ($existingCart as $key => $cart) {
                if ($cart->shipping_place_id && !is_null($cart->product_inner)) {
                    // Selling price calculation

                    if (count($cart->updated_inventory->inventory_attributes) > 0) {
                        $inventoryPrice = (float)$cart->updated_inventory->price;
                    } else {
                        $inventoryPrice = 0;
                    }


                    $selling = (float)$cart->product_inner->selling;
                    $offered = (float)$cart->product_inner->offered;
                    $flashPrice = 0;
                    if (!is_null($cart->product_inner->end_time)) {
                        $flashPrice = (float)$cart->product_inner->price;
                    }
                    if ($inventoryPrice > 0) {
                        $currentPrice = $inventoryPrice;
                    } else if ($flashPrice > 0) {
                        $currentPrice = $flashPrice;
                    } else if ($offered > 0) {
                        $currentPrice = $offered;
                    } else {
                        $currentPrice = $selling;
                    }
                    // Bundle calculation
                    $bundleQtyOffer = 0;
                    $bundleDeal = $cart->product_inner->bundle_deal;
                    if ($bundleDeal) {
                        if ($cart->quantity >= $bundleDeal->buy) {
                            $bundleQtyOffer = $bundleDeal->free;
                        }
                    }
                    $totalPriceWithoutShipping += (float)$currentPrice * ((int)$cart->quantity - $bundleQtyOffer);
                }
            }

            $offeredVoucher = 0;
            $voucher = null;

            if ($request->voucher) {
                $voucher = Voucher::where('code', $request->voucher)
                    ->where('status', Config::get('constants.status.PUBLIC'))
                    ->get()->first();

                if (is_null($voucher)) {
                    return response()->json(Validation::error($request->token,
                        __('lang.invalid_voucher', [], $lang)
                    ));
                }

                if ($totalPriceWithoutShipping < $voucher->min_spend) {
                    $setting = Setting::select('currency', 'currency_icon', 'currency_position')->first();
                    $price = $voucher->min_spend . $setting->currency_icon;

                    if ((int)$setting->currency_position == Config::get('constants.currencyPosition.PRE')) {
                        $price = $setting->currency_icon . $voucher->min_spend;
                    }

                    return response()->json(Validation::error($request->token,
                        __('lang.min_spent', ['amount' => $price], $lang)
                    ));
                }

                $totalOrdered = Order::where('voucher_id', $voucher->id)->count();

                if ($totalOrdered >= $voucher->usage_limit) {
                    return response()->json(Validation::error($request->token,
                        __('lang.voucher_exceeded', [], $lang)
                    ));
                }

                $OrderedByUserQuery = Order::where('voucher_id', $voucher->id);

                if ($request->user_id) {

                    $OrderedByUserQuery = $OrderedByUserQuery->where('user_id', $request->user_id);

                }  else {

                    return response()->json(Validation::errorLang($lang));
                }

                $totalOrderedByUser = $OrderedByUserQuery->count();

                if ($totalOrderedByUser >= $voucher->limit_per_customer) {
                    return response()->json(Validation::error($request->token,
                        __('lang.voucher_max', [], $lang)
                    ));
                }

                $start = new Carbon($voucher->start_time);
                $end = new Carbon($voucher->end_time);
                $now = Carbon::now();

                if ($start >= $now && $now >= $end) {
                    return response()->json(Validation::error($request->token,
                        __('lang.voucher_expired', [], $lang)
                    ));
                }

                if ((int)$voucher->type === (int)Config::get('constants.priceType.FLAT')) {
                    $offeredVoucher = $voucher->price;
                } else {
                    $offeredVoucher = number_format((float)($voucher->price * $totalPriceWithoutShipping) / 100, 2, '.', '');
                }
                if (!is_null($voucher->capped_price) && $offeredVoucher > $voucher->capped_price) {
                    $offeredVoucher = (int)$voucher->capped_price;
                }
            }

            $cartError = [];

            foreach ($existingCart as $c) {
                $productErr = [];
                $error = false;

                if ($c->product->status != Config::get('constants.status.PUBLIC')) {
                    array_push($productErr,
                        __('lang.private_product', ['product' => $c->product->title], $lang)
                    );
                    $error = true;
                }
                if ((int)$c->updated_inventory->quantity < 1) {
                    array_push($productErr,
                        __('lang.out_stock_product', ['product' => $c->product->title], $lang)
                    );
                    $error = true;
                }
                if ($error) {
                    $cartError[$c->id] = $productErr;
                }
            }

            if (count($cartError) > 0) {
                return response()->json(Validation::error($request->token, $cartError, 'product'));
            }

            $setting = Setting::select('currency')->first();

            if (!$voucher) {
                $voucher['id'] = null;
            }


            if (count($existingCart) > 0) {
                $now = Carbon::now();

                $orderArr = [
                    'voucher_id' => $voucher['id'],
                    'currency' => $setting->currency,
                    'updated_at' => $now,
                    'created_at' => $now,
                    'user_address_id' => $request->user_address_id,
                    'user_id' => $request->user_id,
                    'order' => Utils::generateTrackingId(["user_id" => rand(2, 50)]),
                ];

                $order = Order::create($orderArr);

                $posOrder = PosOrder::create([
                    'payment_method' => $request->payment_method,
                    'admin_id' => $this->user->id,
                    'order_id' => $order->id,
                    'offline_trans_id' => $request->offline_trans_id,
                    'offline_payment_method' => $request->offline_payment_method,
                ]);

                Order::where('id', $order->id)->update([
                    'pos_order_id' => $posOrder->id,
                    'payment_done' => true
                ]);

                $orderedProducts = [];
                $totalPrice = 0;

                $shippingId = [];

                foreach ($existingCart as $key => $cart) {

                    if (!is_null($cart->product_inner)) {
                        // Selling price calculation

                        if (count($cart->updated_inventory->inventory_attributes) > 0) {
                            $inventoryPrice = (float)$cart->updated_inventory->price;
                        } else {
                            $inventoryPrice = 0;
                        }


                        $selling = (float)$cart->product_inner->selling;
                        $offered = (float)$cart->product_inner->offered;
                        $flashPrice = null;
                        if (!is_null($cart->product_inner->end_time)) {
                            $flashPrice = (float)$cart->product_inner->price;
                        }
                        if ($inventoryPrice > 0) {
                            $currentPrice = $inventoryPrice;
                        } else if ($flashPrice !== null) {
                            $currentPrice = $flashPrice;
                        } else if ($offered > 0) {
                            $currentPrice = $offered;
                        } else {
                            $currentPrice = $selling;
                        }

                        // Shipping price calculation

                        $shippingPrice = 0;

                        if($cart->shipping_place_id){
                            $currentShippingId = $cart->shipping_place->shipping_rule->id;
                            $cart->shipping_place_id &&

                            $shippingIdExists = key_exists($currentShippingId, $shippingId) &&
                                (int)$shippingId[$currentShippingId] === (int)$cart->shipping_type;

                            if(!$cart->shipping_place->shipping_rule->single_price ||
                                ($cart->shipping_place->shipping_rule->single_price && !$shippingIdExists)) {

                                if ((int)$cart->shipping_type === Config::get('constants.shippingTypeIn.LOCATION')) {
                                    $shippingPrice = $cart->shipping_place->price;
                                } else if ((int)$cart->shipping_type === Config::get('constants.shippingTypeIn.PICKUP')) {
                                    $shippingPrice = $cart->shipping_place->pickup_price;
                                }

                                $shippingId[$currentShippingId] = $cart->shipping_type;
                            }
                        }

                        // Bundle calculation
                        $bundleQtyOffer = 0;
                        $bundleDeal = $cart->product_inner->bundle_deal;
                        if ($bundleDeal) {
                            if ($cart->quantity >= $bundleDeal->buy) {
                                $bundleQtyOffer = $bundleDeal->free;
                            }
                        }


                        // Tax calculation
                        $taxQtyOffer = 0;
                        $taxRule = $cart->product_inner->tax_rules;
                        if ($taxRule) {
                            if ((int)$taxRule->type === (int)Config::get('constants.priceType.FLAT')) {
                                $taxQtyOffer = $taxRule->price;
                            } else {
                                $taxQtyOffer = number_format(
                                    (float)($taxRule->price * $currentPrice) / 100,
                                    2, '.', '');
                            }
                        }

                        $totalTax = (float)($taxQtyOffer * (int)$cart->quantity);
                        $priceWithoutBundle = (float)($currentPrice * ((int)$cart->quantity - (int)$bundleQtyOffer));
                        $total = (float)($shippingPrice + $totalTax + $priceWithoutBundle);

                        $totalPrice += $total;

                        $commission = $cart->product_inner->admin->commission ?? 0;


                        // Inserting ordered product
                        array_push($orderedProducts, [
                            'commission' => $commission,
                            'tax_price' => $taxQtyOffer,
                            'commission_amount' => ($currentPrice * $cart->quantity * $commission) / 100,
                            'product_id' => $cart->product_inner->id,
                            'inventory_id' => $cart->inventory_id,
                            'quantity' => $cart->quantity,
                            'shipping_place_id' => $cart->shipping_place_id,
                            'shipping_type' => $cart->shipping_type,
                            'purchased' => $cart->product_inner->purchased,
                            'bundle_offer' => $bundleQtyOffer,
                            'shipping_price' => $shippingPrice,
                            'selling' => $currentPrice,
                            'withdrawn' => Config::get('constants.withdrawn.NO'),
                            'order_id' => $order->id,
                            'updated_at' => $now,
                            'created_at' => $now
                        ]);

                        UpdatedInventory::where('id', $cart->inventory_id)->decrement('quantity', $cart->quantity);
                    }
                }


                $totalPrice = number_format($totalPrice, 2, '.', '');

                $result = OrderedProduct::insert($orderedProducts);

                if ($result) {

                    Cart::where('admin_id', $this->user->id)
                        ->where('selected', Config::get('constants.status.PUBLIC'))
                        ->delete();


                    $re['currency'] = $setting->currency;
                    $re['amount'] = number_format((float)$totalPrice - $offeredVoucher, 2, '.', '');
                    $re['id'] = $order->id;

                    $re['order'] = $order->order;

                    Order::where('id', $order->id)->update([
                        'total_amount' => $totalPrice - $offeredVoucher,
                    ]);

                    $query = Order::query();
                    $query = $query->with('cancellation');
                    $query = $query->with('address');
                    $query = $query->with(['pos_order' => function($query){
                        $query->with(['admin' => function($query){}]);
                    }]);
                    $query->with(['voucher' => function($query){}]);
                    $query->with(['user' => function($query){}]);


                    if($lang){

                        $query = $query->with(['ordered_products' => function($query) use ($lang){
                            $query->with(['product' => function($query) use ($lang){
                                $query->leftJoin('product_langs as pl',
                                    function ($join) use ($lang) {
                                        $join->on('products.id', '=', 'pl.product_id');

                                        $join->where('pl.lang', $lang);
                                    })
                                    ->select('products.id', 'products.title', 'products.image', 'products.selling',
                                        'products.offered', 'products.shipping_rule_id',
                                        'products.bundle_deal_id', 'products.unit', 'pl.title');
                            }]);
                            $query->with(['updated_inventory' => function($query) use ($lang){
                                $query->with(['inventory_attributes' => function($query) use ($lang){
                                    $query->with(['attribute_value' => function($query) use ($lang){

                                        $query->leftJoin('attribute_value_langs as avl',
                                            function ($join) use ($lang) {
                                                $join->on('attribute_values.id', '=', 'avl.attribute_value_id');
                                                $join->where('avl.lang', $lang);
                                            })
                                            ->with(['attribute' => function ($query) use ($lang) {

                                                $query->leftJoin('attribute_langs as al',
                                                    function ($join) use ($lang) {
                                                        $join->on('attributes.id', '=', 'al.attribute_id');
                                                        $join->where('al.lang', $lang);
                                                    })
                                                    ->select('attributes.id', 'attributes.title', 'al.title');
                                            }])
                                            ->select('attribute_values.*', 'avl.title');
                                    }]);
                                }]);
                            }]);
                        }]);

                    }else {

                        $query = $query->with(['ordered_products' => function($query){
                            $query->with(['product' => function($query){}]);
                            $query->with(['updated_inventory' => function($query){
                                $query->with(['inventory_attributes' => function($query){
                                    $query->with(['attribute_value' => function($query){
                                        $query->with(['attribute' => function($query){}]);
                                    }]);
                                }]);
                            }]);
                        }]);
                    }



                    $query = $query->where('id', $order->id);
                    $data = $query->first();

                    $res = $data;
                    $res['calculated'] = Utils::calcPrice($data);
                    $res['created'] = Utils::formatDate(Utils::convertTimeToUSERzone($data->created_at, $request->time_zone));

                    return response()->json(new Response($request->token, $res));

                }
                return response()->json(Validation::error($request->token,
                    __('lang.went_wrong', [], $lang)
                ));
            }
            return response()->json(Validation::error($request->token,
                __('lang.no_cart', [], $lang)
            ));

        } catch (\Exception $e) {

            return response()->json(Validation::error($request->token, $e->getMessage()));
        }
    }




    public function delete(Request $request, $id)
    {
        try {
            $lang = $request->header('language');

            if ($this->isVendor) {
                return Utils::isDataOwner(null, null);
            }

            $ids = explode(",", $id);

            foreach ($ids as $i) {

                $order = Order::find($i);

                if (is_null($order)) {
                    return response()->json(Validation::nothingFoundLang($lang));
                }

                OrderedProduct::where('order_id', $i)->delete();

                Cancellation::where('order_id', $i)->delete();


                Order::where('id', $i)->update(['pos_order_id' => null]);

                PosOrder::where('order_id', $i)->delete();

                Order::where('id', $i)->delete();

            }


            return response()->json(new Response($request->token, true));


            //return response()->json(Validation::errorTokenLang($request->token, $lang));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


}
