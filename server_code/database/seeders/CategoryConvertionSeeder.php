<?php

namespace Database\Seeders;

use App\Models\Admin;
use App\Models\Banner;
use App\Models\BannerSourceCategory;
use App\Models\BannerSourceSubCategory;
use App\Models\Category;
use App\Models\CategoryLang;
use App\Models\HomeSlider;
use App\Models\HomeSliderSourceCategory;
use App\Models\HomeSliderSourceSubCategory;
use App\Models\SubCategory;
use App\Models\SubCategoryLang;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Config;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class CategoryConvertionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $subCat = SubCategory::get();

        $treeExists1 = Category::where('parent', '!=', 0)->where('parent', '!=', null)->first();




        $admin1 = Admin::where('id', 1)->first();

        if(!$treeExists1 && $admin1 && count($subCat)> 0){





            foreach ($subCat as $i) {
                $cat = Category::create([
                    'id' => $i->id,
                    'title' => $i->title,
                    'status' => $i->status,
                    'image' => $i->image,
                    'admin_id' => $i->admin_id,
                    'featured' => $i->featured,
                    'slug' => $i->slug,
                    'meta_title' => $i->meta_title,
                    'meta_description' => $i->meta_description,
                    'parent' => $i->category_id
                ]);

                $subCatLang = SubCategoryLang::where('sub_category_id', $i->id)->get();

                foreach ($subCatLang as $j) {
                    CategoryLang::create([
                        "category_id" => $cat->id,
                        "title" => $j->title,
                        "meta_title" => $j->meta_title,
                        "meta_description" => $j->meta_description,
                        'lang' => $j->lang
                    ]);
                }
            }


            $bannerSubCat = Banner::where('source_type', Config::get('constants.sliderSourceType.SUB_CATEGORY'))
                ->get();

            foreach ($bannerSubCat as $j) {
                $bannerSrcSubCat = BannerSourceSubCategory::where('banner_id', $j->id)->get();
                foreach ( $bannerSrcSubCat  as $k) {
                    BannerSourceCategory::create([
                        'category_id' => $k->sub_category_id,
                        'banner_id' => $j->id
                    ]);
                    BannerSourceSubCategory::where('id', $k->id)->delete();
                }

                Banner::where('id', $j->id)->update([
                    'source_type' => Config::get('constants.sliderSourceType.CATEGORY')
                ]);
            }


            $homeSliderSubCat = HomeSlider::where('source_type', Config::get('constants.sliderSourceType.SUB_CATEGORY'))
                ->get();

            foreach ($homeSliderSubCat as $j) {
                $homeSliderSrcSubCat = HomeSliderSourceSubCategory::where('home_slider_id', $j->id)->get();
                foreach ( $homeSliderSrcSubCat  as $k) {
                    HomeSliderSourceCategory::create([
                        'category_id' => $k->sub_category_id,
                        'home_slider_id' => $j->id
                    ]);
                    HomeSliderSourceSubCategory::where('id', $k->id)->delete();
                }

                HomeSlider::where('id', $j->id)->update([
                    'source_type' => Config::get('constants.sliderSourceType.CATEGORY')
                ]);
            }

            foreach ($subCat as $i) {

                SubCategoryLang::where('sub_category_id', $i->id)->delete();

                SubCategory::where('id', $i->id)->delete();
            }


            $permissions = Permission::where('group_name', 'subcategory')->get();
            $role = Role::get();

            foreach ($role as $i) {
                $i->permissions()->detach($permissions);
            }

            foreach ($permissions as $permission) {
                $permission->delete();
            }



        }
    }
}
