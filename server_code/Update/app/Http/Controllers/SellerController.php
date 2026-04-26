<?php

namespace App\Http\Controllers;

use App\Models\Admin;
use App\Models\Helper\MailHelper;
use App\Models\Helper\Response;
use App\Models\Helper\Validation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class SellerController extends Controller
{
    public function verify(Request $request)
    {
        try {
            $lang = $request->header('language');

            $validator = Validation::adminVerification($request);
            if ($validator) {
                return response()->json($validator);
            }

            $existingUser = Admin::where('email', request('email'))
                ->first();

            if ($existingUser) {
                if ($existingUser->code == request('code')) {

                    Admin::where('email', $existingUser->email)->update(array('verified' => true));

                    return response()->json(new Response($request->token, $existingUser));

                } else {
                    return response()->json(Validation::error(null,
                        __('lang.code_invalid', [], $lang)
                    ));
                }

            } else {
                return response()->json(Validation::error(null,
                    __('lang.not_exists', [], $lang)
                ));
            }
        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function signup(Request $request)
    {
        try {
            $lang = $request->header('language');


            $validator = Validation::sellersignup($request);
            if ($validator) {
                return response()->json($validator);
            }

            $existingUser = Admin::where('email', request('email'))
                ->first();

            if ($existingUser && $existingUser->verified) {
                return response()->json(Validation::error(null,
                    __('lang.email_verified', [], $lang)
                ));
            }

            $request['username'] = explode(' ', $request['name'])[0];
            $request['password'] = Hash::make(request('password'));


            $request['code'] = MailHelper::codeSender($request, null,
                __('lang.account_registration', [], $lang),
                $lang
            );

            if (!$existingUser) {

                $existingUsername = Admin::where('username', $request->username)->first();

                if($existingUsername && $existingUsername->verified){
                    return response()->json(Validation::error(null,
                        __('lang.user_exists', [], $lang)
                    ));

                } else if(!$existingUsername){

                    Admin::create($request->all());

                } else if($existingUsername){

                    Admin::where('id', $existingUsername->id)->update([
                        'email' => $request['email'],
                        'code' => $request['code'],
                        'password' => $request['password'],
                        'name' => $request['name']
                    ]);
                }



            } else {


                Admin::where('email', $existingUser->email)->update([
                    'code' => $request['code'],
                    'password' => $request['password'],
                    'name' => $request['name']
                ]);
            }

            return response()->json(new Response(null, $request->email));

        } catch (\Exception $ex) {
            return response()->json(Validation::error(null, explode('.', $ex->getMessage())[0]));
        }
    }
}
