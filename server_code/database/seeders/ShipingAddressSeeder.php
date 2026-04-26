<?php

namespace Database\Seeders;

use App\Models\ShippingPlace;
use App\Models\ShippingRule;
use Illuminate\Database\Seeder;

class ShipingAddressSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $sp1 = ShippingPlace::where('id', 1)->first();
        $sp2 = ShippingPlace::where('id', 2)->first();

        if($sp1 && $sp1->id == 1 && $sp1->country == 'ALL' && $sp1->pickup_point == 1  && (int)$sp1->pickup_price == 5){

            ShippingPlace::where('id', 1)->update([
                'pickup_phone' => '6469806576',
                'pickup_address_line_1' => '9400 GLACIER HWY SUITE 1',
                'pickup_address_line_2' => 'JUNEAU JUNEAU AK',
                'pickup_zip' => '99803',
                'pickup_state' => 'New York',
                'pickup_city' => 'New York',
                'pickup_country' => 'USA'
            ]);
        }


        if($sp2 && $sp2->id == 2 && $sp2->country == 'AL' && $sp2->pickup_point == 0 &&
            (int)$sp2->pickup_price == 5 && $sp2->state == '09'){

            ShippingPlace::where('id', 2)->update([
                'pickup_phone' => '698757912',
                'pickup_address_line_1' => 'Bulevardi Zhan D’Ark, Prona nr. 33',
                'pickup_address_line_2' => 'ish-Shtëpia e Ushtarakëve',
                'pickup_zip' => '1001',
                'pickup_state' => 'Tirana',
                'pickup_city' => 'Tirana',
                'pickup_country' => 'Albania'
            ]);
        }


    }
}
