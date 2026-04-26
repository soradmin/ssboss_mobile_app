<?php

namespace Database\Seeders;

use App\Models\Admin;
use App\Models\Language;
use Illuminate\Database\Seeder;

class LanguageSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {

        $superAdmin = Admin::whereHas('roles', function($role) {
            $role->where('name', '=', 'superadmin');
        })->first();

        $items = [
            [
                'name' => 'English',
                'code' => 'en',
                'default' => true,
                'predefined' => true,
                'status' => 1,
            ],
            [
                'name' => 'Turkish',
                'code' => 'tr',
                'status' => 1,
                'predefined' => true,
            ],
            [
                'name' => 'Hindi',
                'code' => 'hi',
                'status' => 1,
                'predefined' => true,
            ],
            [
                'name' => 'Arabic',
                'code' => 'ar',
                'direction' => 'rtl',
                'status' => 1,
                'predefined' => true,
            ],
            [
                'name' => 'French',
                'code' => 'fr',
                'status' => 1,
                'predefined' => true,
            ],
        ];




        if(!Language::first() && $superAdmin){
            foreach ($items as $i) {

                $i['admin_id'] = $superAdmin->id;
                Language::create($i);
            }
        }



    }
}
