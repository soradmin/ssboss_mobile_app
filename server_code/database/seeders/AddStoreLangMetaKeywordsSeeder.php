<?php

namespace Database\Seeders;

use App\Models\Helper\Utils;
use App\Models\StoreLang;
use Illuminate\Database\Seeder;

class AddStoreLangMetaKeywordsSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = StoreLang::get();
        foreach ($items as $item) {
            StoreLang::where('id', $item->id)->update([
                'meta_keywords' => Utils::makeKeyword($item->meta_description)
            ]);
        }
    }
}
