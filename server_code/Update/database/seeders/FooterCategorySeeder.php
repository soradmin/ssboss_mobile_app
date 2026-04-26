<?php

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Config;

class FooterCategorySeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {

        $categories = Category::get();

        foreach ($categories as $i) {
            Category::where('id', $i->id)->update(['in_footer' => Config::get('constants.status.PUBLIC')]);
        }


    }
}
