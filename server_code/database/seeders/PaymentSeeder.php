<?php

namespace Database\Seeders;

use App\Models\Admin;
use App\Models\Payment;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Config;

class PaymentSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = [
            [
                'paypal' => 1,
                'paypal_key' => env('PAYPAL_KEY', ''),
                'paypal_secret' => env('PAYPAL_SECRET', ''),
                'cash_on_delivery' => 1,

                'razorpay_key' => env('RAZORPAY_KEY', ''),
                'razorpay_secret' => env('RAZORPAY_SECRET', ''),
                'stripe_key' => env('STRIPE_KEY', ''),
                'stripe_secret' => env('STRIPE_SECRET', ''),
                'admin_id' => 1,

                'razorpay' => 1,
                'stripe' => 1,
                'flutterwave' => 1,
                'fw_environment' => 'development',
                'fw_public_key' => env('FLW_PUBLIC_KEY', ''),
                'fw_secret_key' => env('FLW_SECRET_KEY', ''),
                'fw_encryption_key' => env('FLW_ENCRYPTION_KEY', ''),
            ]
        ];


        $admin = Admin::where('id', 1)->first();

        if(!Payment::first() && $admin){
            foreach ($items as $i) {
                Payment::create($i);
            }
        }


    }
}
