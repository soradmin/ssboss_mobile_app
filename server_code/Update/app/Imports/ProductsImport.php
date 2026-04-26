<?php

namespace App\Imports;

use App\Models\Attribute;
use App\Models\AttributeValue;
use App\Models\AttributeValueLang;
use App\Models\Brand;
use App\Models\BrandLang;
use App\Models\BundleDeal;
use App\Models\BundleDealLang;
use App\Models\Cart;
use App\Models\Category;
use App\Models\CategoryLang;
use App\Models\CollectionWithProduct;
use App\Models\Helper\Utils;
use App\Models\InventoryAttribute;
use App\Models\OrderedProduct;
use App\Models\Product;
use App\Models\ProductCategory;
use App\Models\ProductCollection;
use App\Models\ProductCollectionLang;
use App\Models\ProductImage;
use App\Models\ProductImageAttribute;
use App\Models\ProductLang;
use App\Models\ShippingRule;
use App\Models\ShippingRuleLang;
use App\Models\TaxRuleLang;
use App\Models\TaxRules;
use App\Models\UpdatedInventory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Str;
use Maatwebsite\Excel\Concerns\ToCollection;

class ProductsImport implements ToCollection
{

    protected $lang;

    public function __construct($lang)
    {
        $this->lang = $lang;
    }


    /**
     * @return \Illuminate\Support\Collection
     */
    public function collection(Collection $rows)
    {
        $lang = $this->lang;

        $adminId = Auth::user()->id;
        // Skip the first row (header/title row)
        $data = $rows->skip(1);


        if ($lang) {

            $brands = Brand::leftJoin('brand_langs as br',
                function ($join) use ($lang) {
                    $join->on('br.brand_id', '=', 'brands.id');
                    $join->where('br.lang', $lang);
                })->select('brands.id', 'br.title');


            $productCollections = ProductCollection::leftJoin('product_collection_langs as pcl',
                function ($join) use ($lang) {
                    $join->on('pcl.product_collection_id', '=', 'product_collections.id');
                    $join->where('pcl.lang', $lang);
                })->select('product_collections.id', 'pcl.title');


            $taxRules = TaxRules::leftJoin('tax_rule_langs as tr',
                function ($join) use ($lang) {
                    $join->on('tr.tax_rule_id', '=', 'tax_rules.id');
                    $join->where('tr.lang', $lang);
                })->select('tax_rules.id', 'tr.title');


            $shippingRules = ShippingRule::leftJoin('shipping_rule_langs as sr',
                function ($join) use ($lang) {
                    $join->on('sr.shipping_rule_id', '=', 'shipping_rules.id');
                    $join->where('sr.lang', $lang);
                })->select('shipping_rules.id', 'sr.title');


            $bundleDeals = BundleDeal::leftJoin('bundle_deal_langs as bd',
                function ($join) use ($lang) {
                    $join->on('bd.bundle_deal_id', '=', 'bundle_deals.id');
                    $join->where('bd.lang', $lang);
                })->select('bundle_deals.id', 'bd.title');

            $categories = Category::leftJoin('category_langs as cl',
                function ($join) use ($lang) {
                    $join->on('cl.category_id', '=', 'categories.id');
                    $join->where('cl.lang', $lang);
                })
                ->select('categories.id', 'cl.title');

            $attrValues = AttributeValue::leftJoin('attribute_value_langs as avl',
                function ($join) use ($lang) {
                    $join->on('avl.attribute_value_id', '=', 'attribute_values.id');
                    $join->where('avl.lang', $lang);
                })
                ->select('attribute_values.id', 'avl.title');

        } else {
            $productCollections = ProductCollection::get();
            $brands = Brand::get();
            $taxRules = TaxRules::get();
            $shippingRules = ShippingRule::get();
            $bundleDeals = BundleDeal::get();
            $categories = Category::get();
            $attrValues = AttributeValue::get();
        }


        $productCollectionsArr = [];
        foreach ($productCollections as $i) {
            $productCollectionsArr[$i->title] = $i->id;
        }

        $brandsArr = [];
        foreach ($brands as $i) {
            $brandsArr[$i->title] = $i->id;
        }

        $taxRulesArr = [];
        foreach ($taxRules as $i) {
            $taxRulesArr[$i->title] = $i->id;
        }

        $shippingRulesArr = [];
        foreach ($shippingRules as $i) {
            $shippingRulesArr[$i->title] = $i->id;
        }

        $bundleDealsArr = [];
        foreach ($bundleDeals as $i) {
            $bundleDealsArr[$i->title] = $i->id;
        }

        $categoriesArr = [];
        foreach ($categories as $i) {
            $categoriesArr[$i->title] = $i->id;
        }

        $attrValuesArr = [];
        foreach ($attrValues as $i) {
            $attrValuesArr[$i->title] = $i->id;
        }

        // Process the data as needed
        foreach ($data as $row) {

            if (count($row) != 27) {
                throw new \Exception(__('lang.invalid_bulk', [], $lang));
            }

            $slug = $row[12];

            if(trim($row[22]) == "") {
                if(trim($slug) == ''){
                    $slug = Str::slug($row[0]);
                }

                $prod = Product::where('slug', $slug)->first();
                $count = 1;
                while ($prod) {
                    $slug = $slug . '-' . $count;
                    $count++;
                    $prod = Product::where('slug', $slug)->first();
                }
            }




            if ($lang) {

                if (!key_exists(trim($row[14]), $taxRulesArr)) {
                    $tr = TaxRules::create([
                        'type' => Config::get('constants.priceType.FLAT'),
                        'admin_id' => $adminId,
                        'title' => ""
                    ]);

                    TaxRuleLang::create([
                        'tax_rule_id' => $tr->id, 'title' => trim($row[14]), 'lang' => $lang
                    ]);

                    $taxRulesArr[trim($row[14])] = $tr->id;
                }


                if (!key_exists(trim($row[15]), $brandsArr)) {
                    $br = Brand::create([
                        'admin_id' => $adminId,
                        'title' => "",
                    ]);

                    BrandLang::create([
                        'brand_id' => $br->id, 'title' => trim($row[15]), 'lang' => $lang
                    ]);

                    $brandsArr[trim($row[15])] = $br->id;
                }

                if (!key_exists(trim($row[16]), $shippingRulesArr)) {
                    $sr = ShippingRule::create([
                        'admin_id' => $adminId,
                        'title' => "",
                    ]);

                    ShippingRuleLang::create([
                        'shipping_rule_id' => $sr->id, 'title' => trim($row[16]), 'lang' => $lang
                    ]);

                    $shippingRulesArr[trim($row[16])] = $sr->id;
                }

                if (!key_exists(trim($row[17]), $bundleDealsArr)) {
                    $bd = BundleDeal::create([
                        'admin_id' => $adminId,
                        'title' => "",
                        'free' => 1,
                        'buy' => 1
                    ]);

                    BundleDealLang::create([
                        'bundle_deal_id' => $bd->id, 'title' => trim($row[17]), 'lang' => $lang
                    ]);

                    $bundleDealsArr[trim($row[17])] = $bd->id;
                }

                $prodData = [
                    'title' => "",
                    'badge' => "",
                    'unit' => "",
                    'description' => "",
                    'overview' => "",
                    'meta_title' => "",
                    'meta_description' => ""
                ];

            } else {

                if (!key_exists(trim($row[14]), $taxRulesArr)) {
                    $tr = TaxRules::create([
                        'type' => Config::get('constants.priceType.FLAT'),
                        'admin_id' => $adminId,
                        'title' => trim($row[14])
                    ]);
                    $taxRulesArr[$tr->title] = $tr->id;
                }

                if (!key_exists(trim($row[15]), $brandsArr)) {
                    $br = Brand::create([
                        'admin_id' => $adminId,
                        'title' => trim($row[15])
                    ]);
                    $brandsArr[$br->title] = $br->id;
                }

                if (!key_exists(trim($row[16]), $shippingRulesArr)) {
                    $sr = ShippingRule::create([
                        'admin_id' => $adminId,
                        'title' => trim($row[16])
                    ]);
                    $shippingRulesArr[$sr->title] = $sr->id;
                }

                if (!key_exists(trim($row[17]), $bundleDealsArr)) {
                    $bd = BundleDeal::create([
                        'admin_id' => $adminId,
                        'title' => trim($row[17]),
                        'free' => 1,
                        'buy' => 1
                    ]);
                    $bundleDealsArr[$bd->title] = $bd->id;
                }

                $prodData = [
                    'title' => $row[0],
                    'badge' => $row[1],
                    'unit' => $row[2],
                    'description' => $row[3],
                    'overview' => $row[4],
                    'meta_title' => $row[5],
                    'meta_description' => $row[6],
                ];
            }


            $productImageName = trim($row[7]);
            if(Utils::isUploadable($productImageName)) {
                $productImageName = Utils::copyImageFromUrl($productImageName, 'product');
            }


            $productVideoName = trim($row[8]);
            if(Utils::isUploadable($productVideoName)) {
                $productVideoName = Utils::copyImageFromUrl($productVideoName, 'product');
            }


            $productVideoThumb = trim($row[9]);
            if(Utils::isUploadable($productVideoThumb)) {
                $productVideoThumb = Utils::copyImageFromUrl($productVideoThumb, 'product');
            }



            $pArr = [
                'image' => $productImageName,
                'video' => $productVideoName,
                'video_thumb' => $productVideoThumb,
                'warranty' => $row[10],
                'refundable' => $row[11],
                'slug' => $slug,
                'tags' => $row[13],
                'tax_rule_id' => $taxRulesArr[trim($row[14])],
                'brand_id' => trim($row[15]) == '' ? null : $brandsArr[trim($row[15])],
                'shipping_rule_id' => $shippingRulesArr[trim($row[16])],
                'bundle_deal_id' => trim($row[17]) == '' ? null : $bundleDealsArr[trim($row[17])],
                'purchased' => $row[18],
                'selling' => $row[19],
                'offered' => $row[20],
                'status' => $row[21],
                'admin_id' => $adminId
            ];

            if (trim($row[22])) {

                $updateArr = [];
                if ($lang) {

                    $updateArr = $pArr;
                } else {

                    $updateArr = array_merge($prodData, $pArr);
                }

                $existingProd = Product::where('id', trim($row[22]))->first();

                if ($existingProd) {
                    if (trim($row[12]) == '') {
                        unset($updateArr['slug']);
                    }

                    Product::where('id', trim($row[22]))->update($updateArr);

                    $prod = new Product();
                    $prod->id = trim($row[22]);

                } else {
                    $prod = Product::create(array_merge($prodData, $pArr));
                }


            } else {

                $prod = Product::create(array_merge($prodData, $pArr));

            }

            if ($lang) {
                $productLang = ProductLang::where('product_id', $prod->id)->first();
                $pLangArr = [
                    'product_id' => $prod->id,
                    'lang' => $lang,
                    'title' => $row[0],
                    'badge' => $row[1],
                    'unit' => $row[2],
                    'description' => $row[3],
                    'overview' => $row[4],
                    'meta_title' => $row[5],
                    'meta_description' => $row[6]
                ];

                if ($productLang) {
                    ProductLang::where('product_id', $prod->id)->update($pLangArr);

                } else {
                    ProductLang::create($pLangArr);
                }

                $pcs = explode(',', trim($row[23]));

                foreach ($pcs as $jk) {
                    if (trim($jk) == '') continue;

                    if (!key_exists(trim($jk), $productCollectionsArr)) {
                        $pc = ProductCollection::create([
                            'admin_id' => $adminId,
                            'title' => "",
                        ]);

                        ProductCollectionLang::create([
                            'product_collection_id' => $pc->id, 'title' => trim($jk), 'lang' => $lang
                        ]);

                        $productCollectionsArr[trim($jk)] = $pc->id;
                    }

                    $existingPc = CollectionWithProduct::where('product_collection_id', $productCollectionsArr[trim($jk)])
                        ->where('product_id', $prod->id)
                        ->first();

                    if (is_null($existingPc)) {
                        CollectionWithProduct::create([
                            'product_collection_id' => $productCollectionsArr[trim($jk)],
                            'product_id' => $prod->id
                        ]);
                    }
                }

            } else {

                $pcs = explode(',', trim($row[23]));

                foreach ($pcs as $jk) {
                    if (trim($jk) == '') continue;


                    if (!key_exists(trim($jk), $productCollectionsArr)) {


                        $pc = ProductCollection::create([
                            'admin_id' => $adminId,
                            'title' => trim($jk)
                        ]);


                        $productCollectionsArr[$pc->title] = $pc->id;
                    }

                    $existingPc = CollectionWithProduct::where('product_collection_id', $productCollectionsArr[trim($jk)])
                        ->where('product_id', $prod->id)
                        ->first();

                    if (is_null($existingPc)) {

                        CollectionWithProduct::create([
                            'product_collection_id' => $productCollectionsArr[trim($jk)],
                            'product_id' => $prod->id
                        ]);

                    }
                }
            }


            $categories = explode(',', $row[24]);

            foreach ($categories as $key => $c) {
                if (trim($c) == '') continue;

                if (!key_exists(trim($c), $categoriesArr)) {

                    if ($lang) {

                        $cat = Category::create([
                            'title' => "",
                            'admin_id' => $adminId
                        ]);

                        CategoryLang::create([
                            'category_id' => $cat->id,
                            'title' => trim($c),
                            'lang' => $lang
                        ]);

                    } else {
                        $cat = Category::create([
                            'title' => trim($c),
                            'admin_id' => $adminId
                        ]);

                    }

                    $categoriesArr[trim($c)] = $cat->id;
                }

                $primary = 0;
                if ($key == 0) {
                    $primary = 1;
                }

                $existingProductCat = ProductCategory::where('category_id', $categoriesArr[trim($c)])
                    ->where('product_id', $prod->id)
                    ->first();

                if (!$existingProductCat) {
                    ProductCategory::create([
                        'category_id' => $categoriesArr[trim($c)],
                        'product_id' => $prod->id,
                        'primary' => $primary
                    ]);
                }
            }


            try {

                $inventories = json_decode(trim($row[25]));


                foreach ($inventories as $inv) {


                    if (trim($inv->attributes) == '') {

                        $existingInv = UpdatedInventory::with('inventory_attributes')
                            ->where('product_id', $prod->id)
                            ->get();


                        if (count($existingInv) == 1 && count($existingInv[0]->inventory_attributes) == 0) {


                            UpdatedInventory::where('id', $existingInv[0]->id)->update([
                                'sku' => $inv->sku,
                                'quantity' => $inv->quantity,
                                'price' => $inv->price
                            ]);


                        } else {

                            foreach ($existingInv as $ei) {
                                InventoryAttribute::where('inventory_id', $ei->id)->delete();
                                UpdatedInventory::where('id', $ei->id)->delete();
                            }

                            UpdatedInventory::create([
                                'product_id' => $prod->id,
                                'sku' => $inv->sku,
                                'quantity' => $inv->quantity,
                                'price' => $inv->price
                            ]);
                        }


                    } else {


                        $attrParts = explode('+', $inv->attributes);


                        $existingAttrInv = [];

                        foreach ($attrParts as $atr) {

                            if (trim($atr) == "") continue;


                            /*For new attribute start*/
                            if (!key_exists(trim($atr), $attrValuesArr)) {
                                if ($lang) {

                                    $attri = Attribute::create([
                                        'admin_id' => $adminId,
                                        'title' => "",
                                    ]);

                                    $av = AttributeValue::create([
                                        'attribute_id' => $attri->id,
                                        'admin_id' => $adminId,
                                        'title' => "",
                                    ]);

                                    AttributeValueLang::create([
                                        'attribute_value_id' => $av->id, 'title' => trim($atr), 'lang' => $lang
                                    ]);

                                    $attrValuesArr[trim($atr)] = $av->id;

                                } else {

                                    $attri = Attribute::create([
                                        'admin_id' => $adminId,
                                        'title' => "",
                                    ]);

                                    $av = AttributeValue::create([
                                        'attribute_id' => $attri->id,
                                        'admin_id' => $adminId,
                                        'title' => trim($atr),
                                    ]);

                                    $attrValuesArr[trim($atr)] = $av->id;
                                }
                            }
                            /*For new attribute end*/

                            $invAttr = InventoryAttribute::where('attribute_value_id', $attrValuesArr[trim($atr)])
                                ->get();

                            $existingAttrInv[trim($atr)] = [];
                            foreach ($invAttr as $ia) {

                                array_push($existingAttrInv[trim($atr)], $ia->inventory_id);

                            }
                        }


                        $invArrays = [];
                        foreach ($existingAttrInv as $ia) {

                            array_push($invArrays, $ia);

                        }


                        $existingInventories = Utils::findCommonElements($invArrays);

                        $existingInv = UpdatedInventory::whereIn('id', $existingInventories)
                            ->where('product_id', $prod->id)->first();


                        if (is_null($existingInv)) {
                            $iv = UpdatedInventory::create([
                                'product_id' => $prod->id,
                                'sku' => $inv->sku,
                                'quantity' => $inv->quantity,
                                'price' => $inv->price

                            ]);

                            foreach ($attrParts as $atr) {

                                if (trim($atr) == "") continue;

                                InventoryAttribute::create([
                                    'inventory_id' => $iv->id,
                                    'attribute_value_id' => $attrValuesArr[trim($atr)]

                                ]);
                            }
                        } else {
                            UpdatedInventory::where('product_id', $prod->id)
                                ->where('id', $existingInv->id)
                                ->update([
                                    'sku' => $inv->sku,
                                    'quantity' => $inv->quantity,
                                    'price' => $inv->price
                                ]);

                        }


                    }

                }

            } catch (\Exception $ex) {
                throw new \Exception('Error in inventory row. ' . $ex->getMessage());
            }


            /*foreach ($inventories as $iv) {

                $inventoriesParts = explode('=>', $iv);


                if (count($inventoriesParts) === 2 && trim($inventoriesParts[1])) {




                    $inventoriesPriceQty = explode('/', trim($inventoriesParts[1]));

                    if (count($inventoriesPriceQty) == 2) {


                        if($prod->id){
                            $existingInv = UpdatedInventory::where('product_id', $prod->id)->get();

                            foreach($existingInv as $ei){
                                $op = OrderedProduct::where('inventory_id', $ei->id)->first();

                                if($op){
                                    throw new \Exception( "Ordered product is using this inventory. Or delete the order. Please make the row empty of 'Inventories' row");
                                }
                                Cart::where('inventory_id', $ei->id)->delete();
                                InventoryAttribute::where('inventory_id', $ei->id)->delete();
                                UpdatedInventory::where('id', $ei->id)->delete();
                            }
                        }


                        $inv = UpdatedInventory::create([
                            'product_id' => $prod->id,
                            'quantity' => trim($inventoriesPriceQty[1]),
                            'price' => trim($inventoriesPriceQty[0])
                        ]);

                        if (trim($inventoriesParts[0])) {
                            $inventoriesAttr = explode('+', trim($inventoriesParts[0]));


                            foreach ($inventoriesAttr as $ivAttr) {

                                if (trim($ivAttr) && key_exists(trim($ivAttr), $attrValuesArr)) {

                                    InventoryAttribute::create([
                                        'inventory_id' => $inv->id,
                                        'attribute_value_id' => $attrValuesArr[trim($ivAttr)]
                                    ]);
                                }
                            }
                        }
                    }
                }
            }*/


            $images = json_decode($row[26]);
            if($images && count($images) > 0){
                foreach ($images as $img) {

                    if(trim($img->image) == '') continue;


                    $imageName = trim($img->image);
                    if(Utils::isUploadable($imageName)) {
                        $imageName = Utils::copyImageFromUrl($imageName, 'product');
                    }

                    $existingImg = ProductImage::where('image', $imageName)
                        ->where('product_id', $prod->id)
                        ->where('admin_id', $adminId)
                        ->first();



                    if (!$existingImg) {
                        $pImg = ProductImage::create([
                            'image' => $imageName,
                            'product_id' => $prod->id,
                            'admin_id' => $adminId
                        ]);

                        if ($img->attributes && count($img->attributes) > 0) {
                            foreach ($img->attributes as $pImgAttr){

                                if(key_exists(trim($pImgAttr), $attrValuesArr)){
                                    ProductImageAttribute::create([
                                        "product_image_id" => $pImg->id,
                                        "attribute_value_id" => $attrValuesArr[trim($pImgAttr)]
                                    ]);
                                }
                            }
                        }

                    } else {
                        if ($img->attributes && count($img->attributes) > 0) {

                            foreach ($img->attributes as $pImgAttr){

                                if(key_exists(trim($pImgAttr), $attrValuesArr)){

                                    $existProdImfAttr = ProductImageAttribute::where("attribute_value_id", $attrValuesArr[trim($pImgAttr)])
                                        ->where("product_image_id", $existingImg->id)
                                        ->first();

                                    if(!$existProdImfAttr){
                                        ProductImageAttribute::create([
                                            "product_image_id" => $existingImg->id,
                                            "attribute_value_id" => $attrValuesArr[trim($pImgAttr)]
                                        ]);
                                    }
                                }
                            }
                        }
                    }
                }


            }


        }
    }
}
