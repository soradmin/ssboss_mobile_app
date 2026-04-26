<?php

namespace Database\Seeders;

use App\Models\CategoryLang;
use App\Models\Helper\Utils;
use Illuminate\Database\Seeder;

class AddCategoryLangMetaKeywordsSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = CategoryLang::get();
        foreach ($items as $item) {
            CategoryLang::where('id', $item->id)->update([
                'meta_keywords' => Utils::makeKeyword($item->meta_description)
            ]);
        }
    }
}
