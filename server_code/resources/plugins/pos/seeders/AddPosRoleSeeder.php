<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class AddPosRoleSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $existingSuperAdmin = Role::where('name', 'superadmin')->first();


        $vendorRole = Role::where('name', 'vendor')->first();

        if(!$existingSuperAdmin){
            return;
        }

        $roleSuperAdmin = Role::findByName('superadmin', 'admin');


        $roleVendor =  null;

        if($vendorRole){
            $roleVendor = Role::findByName('vendor', 'admin');
        }

        $permissions = [
            [
                'group_name' => 'pos',
                'permissions'=> [
                    'pos.view',
                    'pos.create',
                    'pos.edit',
                    'pos.delete'
                ]
            ],
            [
                'group_name' => 'pos_setting',
                'permissions'=> [
                    'pos_setting.view',
                    'pos_setting.create',
                    'pos_setting.edit',
                    'pos_setting.delete'
                ]
            ]
        ];



        $existingPermission = Permission::where('group_name', 'pos')
            ->orWhere('group_name', 'pos_setting')
            ->first();

        // Assign permissions

        if(!$existingPermission){

            for($i = 0; $i < count($permissions); $i++){
                $groupName = $permissions[$i]['group_name'];
                for($j = 0; $j < count($permissions[$i]['permissions']); $j++){

                    $existingPermission = Permission::where('group_name', $groupName)
                        ->where('guard_name', 'admin')
                        ->where('name', $permissions[$i]['permissions'][$j])
                        ->first();

                    if(!$existingPermission){
                        $permission = Permission::create([
                            'group_name' => $groupName,
                            'guard_name' => 'admin',
                            'name' => $permissions[$i]['permissions'][$j]
                        ]);

                        $roleSuperAdmin->givePermissionTo($permission);
                        $permission->assignRole($roleSuperAdmin);

                        if($roleVendor){
                            // Vendor has all permissions except these permissions
                            if(
                                $permissions[$i]['permissions'][$j] !== 'pos.delete' &&
                                $permissions[$i]['permissions'][$j] !== 'pos.view' &&
                                $permissions[$i]['permissions'][$j] !== 'pos.edit' &&
                                $permissions[$i]['permissions'][$j] !== 'pos.create'&&
                                $permissions[$i]['permissions'][$j] !== 'pos_setting.delete' &&
                                $permissions[$i]['permissions'][$j] !== 'pos_setting.view' &&
                                $permissions[$i]['permissions'][$j] !== 'pos_setting.edit' &&
                                $permissions[$i]['permissions'][$j] !== 'pos_setting.create'
                            ){
                                $roleVendor->givePermissionTo($permission);
                                $permission->assignRole($roleVendor);
                            }
                        }
                    }


                }
            }
        }

    }
}
