<?php

namespace Database\Seeders;

use App\Models\Helper\Utils;
use App\Models\ProductLang;
use Illuminate\Database\Seeder;

class AddProductLangMetaKeywords extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = ProductLang::get();
        foreach ($items as $item) {
            ProductLang::where('id', $item->id)->update([
                'meta_keywords' => Utils::makeKeyword($item->meta_description)
            ]);
        }
    }
}
