<?php

namespace Database\Seeders;

use App\Models\Admin;
use App\Models\Store;
use Illuminate\Database\Seeder;

class WhatsappBtnSeeder extends Seeder
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
                'id' => 1,
                'whatsapp_btn' => true,
                'whatsapp_number' => '1234567890',
                'whatsapp_default_msg' => 'I have a question',
            ],

            [
                'id' => 2,
                'whatsapp_btn' => true,
                'whatsapp_number' => '1234567891',
                'whatsapp_default_msg' => 'I have a question',
            ]
        ];



        $storeId = Store::where('id', $items[0])->first();
        $storeId2 = Store::where('id', $items[1])->first();

        if($storeId){
            if(!$storeId->whatsapp_number){
                Store::where('id', $items[0])->update([
                    'whatsapp_btn' => $items[0]['whatsapp_btn'],
                    'whatsapp_number' => $items[0]['whatsapp_number'],
                    'whatsapp_default_msg' => $items[0]['whatsapp_default_msg']
                ]);
            }
        }

        if($storeId2){
            if(!$storeId2->whatsapp_number){
                Store::where('id', $items[1])->update([
                    'whatsapp_btn' => $items[1]['whatsapp_btn'],
                    'whatsapp_number' => $items[1]['whatsapp_number'],
                    'whatsapp_default_msg' => $items[1]['whatsapp_default_msg']
                ]);
            }
        }

    }
}
