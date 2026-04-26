<?php

namespace Database\Seeders;

use App\Models\Helper\Utils;
use App\Models\Store;
use Illuminate\Database\Seeder;

class AddStoreMetaKeywordsSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = Store::get();
        foreach ($items as $item) {
            Store::where('id', $item->id)->update([
                'meta_keywords' => Utils::makeKeyword($item->meta_description)
            ]);
        }
    }
}
