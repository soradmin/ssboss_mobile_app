<?php

namespace Database\Seeders;

use App\Models\Admin;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Config;

class AddAdminStatusSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {


        Admin::where('active', false)->update([
            'active' => true
        ]);

        Admin::where('verified', false)->update([
          'verified' => true
        ]);
    }
}
