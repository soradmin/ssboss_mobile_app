<?php

namespace Database\Seeders;

use App\Models\Helper\Utils;
use App\Models\Page;
use Illuminate\Database\Seeder;

class AddPageMetaKeywordsSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = Page::get();
        foreach ($items as $item) {
            Page::where('id', $item->id)->update([
                'meta_keywords' => Utils::makeKeyword($item->meta_description)
            ]);
        }
    }
}
