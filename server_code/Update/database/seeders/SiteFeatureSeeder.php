<?php

namespace Database\Seeders;

use App\Models\SiteFeature;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Config;

class SiteFeatureSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $banners = [
            [
                'id' => 1,
                'image' => 'site-feature-1.webp',

                'detail' => '<h4><strong>Rapid shipping</strong></h4><p>With a short period of time</p>',
                'status' => Config::get('constants.status.PUBLIC'),
            ],
            [
                'id' => 2,
                'image' => 'site-feature-2.webp',

                'detail' => '<h4><strong>Secure transaction</strong></h4><p>Checkout securely</p>',
                'status' => Config::get('constants.status.PUBLIC'),
            ],
            [
                'id' => 3,
                'image' => 'site-feature-3.webp',

                'detail' => '<h4><strong>24/7 support</strong></h4><p>Ready to pickup calls</p>',
                'status' => Config::get('constants.status.PUBLIC'),
            ],
            [
                'id' => 4,
                'image' => 'site-feature-4.webp',

                'detail' => '<h4><strong>Bundle offer</strong></h4><p>On many products</p>',
                'status' => Config::get('constants.status.PUBLIC'),
            ]
        ];

        if(!SiteFeature::first()){
            foreach ($banners as $i) {
                SiteFeature::create($i);
            }
        }
    }
}
