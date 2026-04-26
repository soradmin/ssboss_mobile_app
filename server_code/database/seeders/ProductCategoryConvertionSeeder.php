<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Product;
use App\Models\ProductCategory;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;

class ProductCategoryConvertionSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {



        $productCategories = ProductCategory::first();

        if(!$productCategories){


            $hasCol = Schema::hasColumn('products', 'category_id');


            $hasCategoryProduct = Product::where('category_id', 0)->first();


            if($hasCol && !$hasCategoryProduct){



                $products = Product::select('id', 'category_id', 'subcategory_id')->get();
                foreach ($products as $i) {

                    if($i->subcategory_id){
                        ProductCategory::create([
                            'primary' => true,
                            'category_id' => $i->subcategory_id,
                            'product_id' => $i->id,
                        ]);
                    }

                    if($i->category_id){
                        ProductCategory::create([
                            'category_id' => $i->category_id,
                            'product_id' => $i->id,
                        ]);
                    }
                }





            } else {


                $cat1 = Category::where('id', 63082111)->first();
                $cat2 = Category::where('id', 96674111)->first();
                $cat3 = Category::where('id', 72531155)->first();
                $cat4 = Category::where('id', 96522110)->first();
                $cat5 = Category::where('id', 96765114)->first();
                $cat6 = Category::where('id', 99585125)->first();
                $cat7 = Category::where('id', 99585122)->first();
                $cat8 = Category::where('id', 97373115)->first();
                $cat9 = Category::where('id', 99585134)->first();
                $cat10 = Category::where('id', 99585149)->first();


                $p1 = Product::where('id', 88630111)->first();
                $p2 = Product::where('id', 88630114)->first();
                $p3 = Product::where('id', 88630118)->first();
                $p4 = Product::where('id', 88630119)->first();
                $p5 = Product::where('id', 88630122)->first();
                $p6 = Product::where('id', 88630125)->first();
                $p7 = Product::where('id', 88630130)->first();
                $p8 = Product::where('id', 88630146)->first();
                $p9 = Product::where('id', 88630160)->first();
                $p10 = Product::where('id', 88630163)->first();



                $catExists = $cat1 && $cat2 && $cat3 && $cat4 && $cat5 && $cat6 && $cat7 && $cat8 && $cat9 && $cat10;
                $prodExists = $p1 && $p2 && $p3 && $p4 && $p5 && $p6 && $p7 && $p8 && $p9 && $p10;


                if($catExists && $prodExists){



                    $pc['88630111'] = [63082111, 64273111];
                    $pc['88630112'] = [63082111, 64273111];
                    $pc['88630113'] = [63082111, 64273111];
                    $pc['88630114'] = [63082111, 64273111];
                    $pc['88630115'] = [63082111, 64273111];
                    $pc['88630116'] = [63082111, 64273111];
                    $pc['88630117'] = [63082111, 64273111];
                    $pc['88630118'] = [63082111, 73294112];
                    $pc['88630119'] = [63082111, 73294112];
                    $pc['88630120'] = [63082111, 73294112];
                    $pc['88630121'] = [63082111, 73294112];
                    $pc['88630122'] = [63082111, 96323113];
                    $pc['88630123'] = [63082111, 96323113];
                    $pc['88630124'] = [63082111, 96765114];
                    $pc['88630125'] = [63082112, 97373115];
                    $pc['88630126'] = [63082112, 97373115];
                    $pc['88630127'] = [63082112, 97373116];
                    $pc['88630128'] = [63082112, 97373117];
                    $pc['88630129'] = [63082112, 97373117];
                    $pc['88630130'] = [63082112, 97373117];
                    $pc['88630131'] = [63082112, 97373117];
                    $pc['88630132'] = [72531155, 73294118];
                    $pc['88630133'] = [72531155, 96323119];
                    $pc['88630134'] = [72531155, 96765110];
                    $pc['88630135'] = [72531153, 99585122];
                    $pc['88630136'] = [72531153, 99585122];
                    $pc['88630137'] = [72531153, 99585122];
                    $pc['88630138'] = [61952111, 97373124];
                    $pc['88630139'] = [61952111, 97373124];
                    $pc['88630140'] = [61952111, 97373124];
                    $pc['88630141'] = [61952111, 99585125];
                    $pc['88630142'] = [61952111, 99585125];
                    $pc['88630143'] = [61952111, 99585125];
                    $pc['88630144'] = [61952111, 99585125];
                    $pc['88630145'] = [61952111, 96765126];
                    $pc['88630146'] = [61952111, 99585127];
                    $pc['88630147'] = [61952111, 99585128];
                    $pc['88630148'] = [61952111, 99585128];
                    $pc['88630149'] = [61952111, 99585128];
                    $pc['88630150'] = [96522110, 99585130];
                    $pc['88630151'] = [96522110, 99585130];
                    $pc['88630152'] = [72533143, 99585133];
                    $pc['88630153'] = [72533143, 99585133];
                    $pc['88630154'] = [72533143, 99585134];
                    $pc['88630155'] = [72533143, 99585134];
                    $pc['88630156'] = [96674111, 99585136];
                    $pc['88630157'] = [96674111, 99585136];
                    $pc['88630158'] = [96674111, 99585136];
                    $pc['88630159'] = [91202114, 96765141];
                    $pc['88630160'] = [92522115, 99585143];
                    $pc['88630161'] = [92522115, 96765144];
                    $pc['88630162'] = [92522115, 96765144];
                    $pc['88630163'] = [91233119, 99585149];


                    $arr = [];
                    foreach ($pc as  $key => $value) {
                        foreach ($value as $k => $i) {
                            $primary = 0;
                            if($k == 0){
                                $primary = 1;
                            }

                            array_push($arr, [
                                'primary' => $primary,
                                'category_id' => $i,
                                'product_id' => $key,
                            ]);
                        }
                    }

                    ProductCategory::insert($arr);


                }


            }

        }
    }
}
