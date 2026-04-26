<?php

namespace Database\Seeders;

use App\Models\Helper\Utils;
use App\Models\SiteSettingLang;
use Illuminate\Database\Seeder;

class AddSiteSettingLangMetaKeywordsSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = SiteSettingLang::get();
        foreach ($items as $item) {
            SiteSettingLang::where('id', $item->id)->update([
                'meta_keywords' => Utils::makeKeyword($item->meta_description)
            ]);
        }
    }
}
