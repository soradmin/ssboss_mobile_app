<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Helper\Utils;
use Illuminate\Database\Seeder;

class AddCategoryMetaKeywordsSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = Category::get();
        foreach ($items as $item) {
            Category::where('id', $item->id)->update([
                'meta_keywords' => Utils::makeKeyword($item->meta_description)
            ]);
        }
    }
}
