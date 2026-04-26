<?php

namespace Database\Seeders;

use App\Models\Admin;
use App\Models\Payment;
use Illuminate\Database\Seeder;

class AddPayFastPaymentSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $admin = Admin::where('id', 1)->first();
        $payment = Payment::first();

        if($payment && $admin){
            Payment::where('id', $payment->id)->update([
                'payfast_payment' => true,
                'payfast_base_url' => 'https://sandbox.payfast.co.za',
                'payfast_merchant_id' => '10034290',
                'payfast_merchant_key' => 'r37d15l67dgd1',
                'payfast_passphrase' => '23er2423redwdw'
            ]);
        }
    }
}
