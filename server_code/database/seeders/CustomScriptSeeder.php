<?php

namespace Database\Seeders;

use App\Models\CustomScript;
use Illuminate\Database\Seeder;

class CustomScriptSeeder extends Seeder
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
                'status' => 1,
                'route_pattern' => '/*',
                'header_script' => true,
                'header_script_code' => "console.log('Calling from common header')",
            ],
            [
                'id' => 2,
                'status' => 1,
                'route_pattern' => '/*/product/*',
                'body_script' => true,
                'body_script_code' => "console.log('Calling from product body')",
            ]
        ];


        $cs = CustomScript::first();


        if(!$cs){
            foreach ($items as $i) {
                CustomScript::create($i);
            }
        }
    }
}
