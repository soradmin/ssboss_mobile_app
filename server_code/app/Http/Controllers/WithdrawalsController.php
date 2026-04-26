<?php

namespace App\Http\Controllers;

use App\Models\Helper\ControllerHelper;
use App\Models\Helper\Response;
use App\Models\Helper\Utils;
use App\Models\Helper\Validation;
use App\Models\OrderedProduct;
use App\Models\Withdrawal;
use App\Models\WithdrawalAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Config;

class WithdrawalsController extends ControllerHelper
{
    public function all(Request $request)
    {
        try {
            if ($can = Utils::userCan($this->user, 'withdrawal_request.view')) {
                return $can;
            }

            $query = Withdrawal::with('approved_admin')
                ->with('withdrawal_account')
                ->orderBy($request->orderby, $request->type);

            if ($this->isVendor) {
                $query = $query->where('admin_id', $this->user->id);
            }

            if ($request->q) {
                $query = $query->where('title', 'LIKE', "%{$request->q}%");
            }
            $data = $query->paginate(Config::get('constants.api.PAGINATION'));

            if ($request->time_zone) {
                foreach ($data as $item) {
                    $item['created'] =
                        Utils::formatDate(Utils::convertTimeToUSERzone($item->created_at, $request->time_zone));
                }
            } else {
                foreach ($data as $item) {
                    $item['created'] = Utils::formatDate($item->created_at);
                }
            }

            return response()->json(new Response($request->token, $data));
        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }

    public function find(Request $request)
    {
        try {
            if ($can = Utils::userCan($this->user, 'withdrawal_request.create')) {
                return $can;
            }

            $ordered = OrderedProduct::join('products as p', function ($join) {
                $join->on('p.id', '=', 'ordered_products.product_id');
                $join->where('p.admin_id', $this->user->id);
            })->join('orders as o', function ($join) {
                $join->on('o.id', '=', 'ordered_products.order_id');
                $join->where('o.payment_done', true);
            });

            $ordered = $ordered->where('withdrawn', Config::get('constants.withdrawn.NO'));
            $ordered = $ordered->select('p.*', 'ordered_products.*');
            $ordered = $ordered->get();


            $commissionTotal = 0;
            $sellingTotal = 0;


            foreach ($ordered as $i){
                $commissionTotal += $i->commission_amount;
                $sellingTotal += $i->selling * ($i->quantity - $i->bundle_offer);
            }


            $withdrawnAmount = Withdrawal::with('approved_admin')
                ->where('admin_id', $this->user->id)
                ->where('status', Config::get('constants.status.PUBLIC'))
                ->sum('amount');

            $pendingWithdrawalAmount = Withdrawal::with('approved_admin')
                ->where('admin_id', $this->user->id)
                ->where('status', Config::get('constants.status.PRIVATE'))
                ->sum('amount');

            $data['pending_withdrawal'] = $pendingWithdrawalAmount;
            $data['withdrawn'] = $withdrawnAmount;
            $data['amount'] = $sellingTotal - $commissionTotal;

            return response()->json(new Response($request->token, $data));
        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function withdrawCancel(Request $request)
    {
        try {
            $lang = $request->header('language');

            if ($can = Utils::userCan($this->user, 'withdrawal_request.cancel')) {
                return $can;
            }

            $validate = Validation::withdrawalCancel($request);
            if ($validate) {
                return response()->json($validate);
            }

            $withdrawal = Withdrawal::find($request->id);

            if (is_null($withdrawal)) {
                return response()->json(Validation::noDataLang($lang));
            }

            if ($this->isVendor && $isOwner = Utils::isDataOwner($this->user, $withdrawal)) {
                return $isOwner;
            }

            Withdrawal::where('id', $request->id)->update([
                'message' => $request->message,
                'status' => Config::get('constants.withdrawalStatus.CANCELLED')
            ]);

            OrderedProduct::where('withdrawal_id', $request->id)
                ->update([
                    'withdrawn' => Config::get('constants.withdrawn.NO'),
                ]);


            return response()->json(new Response($request->token, true));
        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }

    public function withdrawApprove(Request $request)
    {
        try {
            $lang = $request->header('language');

            if ($can = Utils::userCan($this->user, 'withdrawal_request.approve')) {
                return $can;
            }

            $validate = Validation::withdrawalApprove($request);
            if ($validate) {
                return response()->json($validate);
            }

            $withdrawal = Withdrawal::find($request->id);

            if (is_null($withdrawal)) {
                return response()->json(Validation::noDataLang($lang));
            }

            if ($this->isVendor && $isOwner = Utils::isDataOwner($this->user, $withdrawal)) {
                return $isOwner;
            }

            Withdrawal::where('id', $request->id)->update([
                'message' => $request->message,
                'status' => Config::get('constants.withdrawalStatus.APPROVED')
            ]);


            OrderedProduct::where('withdrawal_id', $request->id)
                ->update([
                    'withdrawn' => Config::get('constants.withdrawn.YES'),
                ]);

            return response()->json(new Response($request->token, true));
        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function withdrawMoney(Request $request)
    {
        try {

            $lang = $request->header('language');
            if ($can = Utils::userCan($this->user, 'withdrawal_request.create')) {
                return $can;
            }

            $ordered = OrderedProduct::join('products as p', function ($join) {
                $join->on('p.id', '=', 'ordered_products.product_id');
                $join->where('p.admin_id', $this->user->id);
            });

            $ordered = $ordered->where('withdrawn', Config::get('constants.withdrawn.NO'));
            $ordered = $ordered->select('p.*', 'ordered_products.*');
            $ordered = $ordered->get();


            $commissionTotal = 0;
            $sellingTotal = 0;


            foreach ($ordered as $i){
                $commissionTotal += $i->commission_amount;
                $sellingTotal += $i->selling * ($i->quantity - $i->bundle_offer);
            }

            $pendingWithdrawalAmount = Withdrawal::with('approved_admin')
                ->where('admin_id', $this->user->id)
                ->where('status', Config::get('constants.status.PRIVATE'))
                ->sum('amount');

            $balance = $sellingTotal - $commissionTotal;

            if ((int)$balance < Config::get('constants.withdraw.MIN_AMOUNT')) {
                return response()->json(Validation::error($request->token,
                    __('lang.insufficient_balance', [], $lang)
                ));
            }

            if ((int)$pendingWithdrawalAmount > 0) {
                return response()->json(Validation::error($request->token,
                    __('lang.pending_request', [], $lang)
                ));
            }

            $withdrawalAccount = WithdrawalAccount::where('admin_id', $this->user->id)
                ->where('default', Config::get('constants.status.PUBLIC'))
                ->first();

            if (is_null($withdrawalAccount)) {
                return response()->json(Validation::error($request->token,
                    __('lang.no_account', [], $lang)
                ));
            }

            // Create withdrawal request
            $withdrawn = Withdrawal::create([
                'amount' => $balance,
                'withdrawal_account_id' => $withdrawalAccount->id,
                'admin_id' => $this->user->id
            ]);

            OrderedProduct::where('withdrawn', Config::get('constants.withdrawn.NO'))
                ->update([
                    'withdrawn' => Config::get('constants.withdrawn.PENDING'),
                    'withdrawal_id' => $withdrawn->id
                ]);


            // Fetching data in order to get the updated data
            $ordered = OrderedProduct::join('products as p', function ($join) {
                $join->on('p.id', '=', 'ordered_products.product_id');
                $join->where('p.admin_id', $this->user->id);
            });
            $ordered = $ordered->where('withdrawn', Config::get('constants.withdrawn.NO'));
            $commissionTotal = $ordered->sum('ordered_products.commission_amount');
            $sellingQuery = $ordered->selectRaw('SUM(ordered_products.selling * ordered_products.quantity) as total_sum')->first();
            $sellingTotal = $sellingQuery->total_sum;

            $withdrawnAmount = Withdrawal::with('approved_admin')
                ->where('admin_id', $this->user->id)
                ->where('status', Config::get('constants.status.PUBLIC'))
                ->sum('amount');

            $pendingWithdrawalAmount = Withdrawal::with('approved_admin')
                ->where('admin_id', $this->user->id)
                ->where('status', Config::get('constants.status.PRIVATE'))
                ->sum('amount');

            $data['pending_withdrawal'] = $pendingWithdrawalAmount;
            $data['withdrawn'] = $withdrawnAmount;
            $data['amount'] = $sellingTotal - $commissionTotal;

            return response()->json(new Response($request->token, $data));
        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }

    public function delete(Request $request, $id)
    {
        try {
            $lang = $request->header('language');


            if ($can = Utils::userCan($this->user, 'withdrawal_request.delete')) {
                return $can;
            }


            $ids = explode(",", $id);

            foreach ($ids as $i) {

                $withdrawal = Withdrawal::find($i);

                if ($this->isVendor && $isOwner = Utils::isDataOwner($this->user, $withdrawal)) {
                    return $isOwner;
                }

                if (is_null($withdrawal)) {
                    return response()->json(Validation::noDataLang($lang));
                }

                OrderedProduct::where('withdrawn', Config::get('constants.withdrawn.PENDING'))
                    ->update([
                        'withdrawn' => Config::get('constants.withdrawn.NO'),
                    ]);

                OrderedProduct::where('withdrawal_id', $i)
                    ->update([
                        'withdrawal_id' => null,
                    ]);

                $withdrawal->delete();
            }

            return response()->json(new Response($request->token, true));

           // return response()->json(Validation::error($request->token, null, 'form', $lang));


        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }

}
