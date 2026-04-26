<?php

namespace Database\Seeders;

use App\Models\Helper\Utils;
use App\Models\Product;
use Illuminate\Database\Seeder;

class AddProductMetaKeywords extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = Product::get();
        foreach ($items as $item) {
            Product::where('id', $item->id)->update([
                'meta_keywords' => Utils::makeKeyword($item->meta_description)
            ]);
        }
    }
}
