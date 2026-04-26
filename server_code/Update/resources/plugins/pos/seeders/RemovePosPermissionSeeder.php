<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;

class RemovePosPermissionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        Permission::where('group_name', 'pos')
            ->orWhere('group_name', 'pos_setting')
            ->delete();
    }
}
