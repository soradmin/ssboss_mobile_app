<?php

namespace Database\Seeders;

use App\Models\Payment;
use Illuminate\Database\Seeder;

class AddBankPaymentSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $payment = Payment::first();
        if ($payment) {
            Payment::where('id', $payment->id)
                ->update([
                    'bank' => true,
                    'bank_name' => 'First Century Bank',
                    'branch_name' => 'GA',
                    'account_name' => 'John Doe',
                    'account_number' => '5361147767209',
                ]);
        }
    }
}
