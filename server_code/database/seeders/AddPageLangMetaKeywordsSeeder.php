<?php

namespace Database\Seeders;

use App\Models\Helper\Utils;
use App\Models\PageLang;
use Illuminate\Database\Seeder;

class AddPageLangMetaKeywordsSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = PageLang::get();
        foreach ($items as $item) {
            PageLang::where('id', $item->id)->update([
                'meta_keywords' => Utils::makeKeyword($item->meta_description)
            ]);
        }
    }
}
