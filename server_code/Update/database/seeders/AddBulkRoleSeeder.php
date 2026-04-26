<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class AddBulkRoleSeeder extends Seeder
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
                'group_name' => 'bulk_upload',
                'permissions'=> [
                    'bulk_upload.view',
                    'bulk_upload.create',
                    'bulk_upload.edit',
                ]
            ]
        ];


        // Assign permissions
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
                            $permissions[$i]['permissions'][$j] !== 'bulk_upload.view' &&
                            $permissions[$i]['permissions'][$j] !== 'bulk_upload.delete' &&
                            $permissions[$i]['permissions'][$j] !== 'bulk_upload.edit'
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
