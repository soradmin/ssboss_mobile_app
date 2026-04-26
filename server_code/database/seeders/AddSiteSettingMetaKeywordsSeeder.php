<?php

namespace Database\Seeders;

use App\Models\Helper\Utils;
use App\Models\SiteSetting;
use Illuminate\Database\Seeder;

class AddSiteSettingMetaKeywordsSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = SiteSetting::get();
        foreach ($items as $item) {
            SiteSetting::where('id', $item->id)->update([
                'meta_keywords' => Utils::makeKeyword($item->meta_description)
            ]);
        }
    }
}
