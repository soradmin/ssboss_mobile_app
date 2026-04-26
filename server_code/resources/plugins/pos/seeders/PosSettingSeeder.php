<?php

namespace Database\Seeders;

use App\Models\Admin;
use App\Models\PosOrder;
use App\Models\PosSetting;
use Illuminate\Database\Seeder;

class PosSettingSeeder extends Seeder
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
                'width' => 300,
                'image' => 'pos-logo.svg',
                'address' => '13th Street. 47 W 13th St, New York, NY 10011, USA',
                'header_text' => 'Central VAT reg no: 000333-54545454',
                'footer_text' => '**VAT against this challan is payable through central registration. Thank you for your shopping with ISHOP. For any queries, suggestions, or complaints, please call 12345(9.00 AM - 6.00 PM)',
                'is_default' => 1,
                'admin_id' => 1,
            ]
        ];


        $admin = Admin::where('id', 1)->first();

        if(!PosSetting::first() && $admin){
            foreach ($items as $i) {
                PosSetting::create($i);
            }
        }
    }
}
