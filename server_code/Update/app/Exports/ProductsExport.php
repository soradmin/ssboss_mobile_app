<?php

namespace App\Exports;

use App\Models\Product;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\WithHeadings;

class ProductsExport implements FromCollection, WithHeadings
{

    protected $lang;

    public function __construct($lang)
    {
        $this->lang = $lang;
    }

    /**
    * @return \Illuminate\Support\Collection
    */
    public function collection()
    {
        $query = Product::query();
        $lang = $this->lang;

        $selectArr = [
            'products.image',
            'products.video',
            'products.video_thumb',
            'products.warranty',
            'products.refundable',
            'products.slug',
            'products.tags',
            'tr.title as tax_rule',
            'b.title as brand',
            'sr.title as shipping_rule',
            'bd.title as bundle_deal',
            'products.purchased',
            'products.selling',
            'products.offered',
            'products.status',
            'products.id'
        ];




        if ($lang) {


            $query = $query->with(['product_images.attributes.value' =>
                function ($query) use ($lang) {

                    $query->leftJoin('attribute_value_langs as avl', function ($join) use ($lang) {
                        $join->on('avl.attribute_value_id', '=', 'attribute_values.id');
                        $join->where('avl.lang', $lang);
                    }) ->select('attribute_values.*', 'avl.title');}
            ]);


            $query = $query->with(['product_collections.collection' =>
                function ($query) use ($lang) {

                    $query->leftJoin('product_collection_langs as pcl', function ($join) use ($lang) {
                        $join->on('pcl.product_collection_id', '=', 'product_collections.id');
                        $join->where('pcl.lang', $lang);
                    }) ->select('product_collections.*', 'pcl.title');}
            ]);

            $query = $query->with(['product_inventories.inventory_attributes.attribute_value' =>
                function ($query) use ($lang) {

                    $query->leftJoin('attribute_value_langs as avl', function ($join) use ($lang) {
                        $join->on('avl.attribute_value_id', '=', 'attribute_values.id');
                        $join->where('avl.lang', $lang);
                    }) ->select('attribute_values.*', 'avl.title');}
            ]);


            $query = $query->leftJoin('product_langs as pl', function ($join) use ($lang) {
                $join->on('pl.product_id', '=', 'products.id');
                $join->where('pl.lang', $lang);
            });

            $query = $query->leftJoin('tax_rule_langs as tr',
                function ($join) use ($lang) {
                    $join->on('tr.tax_rule_id', '=', 'products.tax_rule_id');
                    $join->where('tr.lang', $lang);
                });

            $query = $query->leftJoin('brand_langs as b',
                function ($join) use ($lang) {
                    $join->on('b.brand_id', '=', 'products.brand_id');
                    $join->where('b.lang', $lang);
                });

            $query = $query->leftJoin('shipping_rule_langs as sr',
                function ($join) use ($lang) {
                    $join->on('sr.shipping_rule_id', '=', 'products.shipping_rule_id');
                    $join->where('sr.lang', $lang);
                });

            $query = $query->leftJoin('bundle_deal_langs as bd',
                function ($join) use ($lang) {
                    $join->on('bd.bundle_deal_id', '=', 'products.bundle_deal_id');
                    $join->where('bd.lang', $lang);
                });



            $query = $query->with(['product_categories.category' => function ($query) use ($lang) {
                $query->leftJoin('category_langs as cl', function ($join) use ($lang) {
                    $join->on('cl.category_id', '=', 'categories.id');
                    $join->where('cl.lang', $lang);
                })
                    ->select('categories.*', 'cl.title');
            }]);


            $selectArr = array_merge([
                'pl.title',
                'pl.badge',
                'pl.unit',
                'pl.description',
                'pl.overview',
                'pl.meta_title',
                'pl.meta_description'], $selectArr);

        } else {

            $query = $query->with(['product_images.attributes.value']);

            $query = $query->with(['product_collections.collection']);

            $query = $query->with(['product_inventories.inventory_attributes.attribute_value']);



            $query = $query->with(['product_categories.category']);

            $query = $query->leftJoin('tax_rules as tr',
                function ($join) use ($lang) {
                    $join->on('tr.id', '=', 'products.tax_rule_id');
                });

            $query = $query->leftJoin('brands as b',
                function ($join) use ($lang) {
                    $join->on('b.id', '=', 'products.brand_id');
                });

            $query = $query->leftJoin('shipping_rules as sr',
                function ($join) use ($lang) {
                    $join->on('sr.id', '=', 'products.shipping_rule_id');
                });

            $query = $query->leftJoin('bundle_deals as bd',
                function ($join) use ($lang) {
                    $join->on('bd.id', '=', 'products.bundle_deal_id');
                });

            $selectArr = array_merge([
                'products.title',
                'products.badge',
                'products.unit',
                'products.description',
                'products.overview',
                'products.meta_title',
                'products.meta_description'
            ], $selectArr);
        }


        $query = $query->select($selectArr);


        $all = $query->get();

        foreach ($all as $i){

            $productCollections = [];
            foreach ($i->product_collections as $j) {
                array_push($productCollections, $j->collection->title);
            }

            $i['collections'] = join(', ', $productCollections);



            $categories = [];
            foreach ($i->product_categories as $j) {
                array_push($categories, $j->category->title);
            }

            $i['categories'] = join(', ', $categories);


            $inventories = [];
            foreach ($i->product_inventories as $k){

                $invAttr = [];
                foreach ($k->inventory_attributes as $l) {

                    array_push($invAttr, $l->attribute_value->title);

                }

                $inv['attributes'] = join(' + ', $invAttr);


                $inv['sku'] = $k->sku ? $k->sku : '';
                $inv['price'] = $k->price;
                $inv['quantity'] = $k->quantity;

                array_push($inventories, $inv);

            }
            $i['inventories'] = json_encode($inventories);




            $images = [];
            foreach ($i->product_images as $k){

                $img['image'] = $k->image;
                $img['attributes'] = [];




                if(count($k->attributes) > 0) {
                    foreach ($k->attributes as $l){

                        if($l->value){
                            array_push($img['attributes'], $l->value->title);
                        }

                    }
                }
                array_push($images, $img);
            }

            if(count($images) > 0){

                $i['images'] = json_encode($images);
            } else {

                $i['images'] = "";
            }




            unset($i['product_images']);
            unset($i['product_inventories']);
            unset($i['product_categories']);
            unset($i['product_collections']);
        }

        return $all;
    }



    public function headings(): array
    {
        // Define your headings here
        return [
            'Title',
            'Badge',
            'Unit',
            'Description',
            'Overview',
            'Meta title',
            'Meta description',
            'Image',
            'Video',
            'Video thumb',
            'Warranty',
            'Refundable',
            'Slug',
            'Tags',
            'Tax rule',
            'Brand',
            'Shipping rule',
            'Bundle deal',
            'Purchased',
            'Selling',
            'Offered',
            'Status',
            'Id',
            'Collections',
            'Categories',
            'Inventories',
            'Images',
        ];
    }
}
