<?php

namespace Database\Seeders;

use App\Models\SiteFeatureLang;
use Illuminate\Database\Seeder;

class SiteFeatureLangSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $banners = [
            [
                'site_feature_id' => 1,
                'detail' => '<h4><strong>Hızlı kargo</strong></h4><p>Kısa bir süre ile</p>',
                'lang' => 'tr'
            ],
            [
                'site_feature_id' => 2,
                'detail' => '<h4><strong>Güvenli işlem</strong></h4><p>Güvenli ödeme</p>',
                'lang' => 'tr'
            ],
            [
                'site_feature_id' => 3,
                'detail' => '<h4><strong>7/24 destek</strong></h4><p>Çağrıları almaya hazır</p>',
                'lang' => 'tr'
            ],
            [
                'site_feature_id' => 4,
                'detail' => '<h4><strong>Paket teklifi</strong></h4><p>Birçok üründe</p>',
                'lang' => 'tr'
            ],


            [
                'site_feature_id' => 1,
                'detail' => '<h4><strong>रैपिड शिपिंग</strong></h4><p>कम समय के साथ</p>',
                'lang' => 'hi'
            ],
            [
                'site_feature_id' => 2,
                'detail' => '<h4><strong>सुरक्षित लेनदेन</strong></h4><p>सुरक्षित रूप से चेकआउट करें</p>',
                'lang' => 'hi'
            ],
            [
                'site_feature_id' => 3,
                'detail' => '<h4><strong>24/7 समर्थन</strong></h4><p>कॉल लेने के लिए तैयार</p>',
                'lang' => 'hi'
            ],
            [
                'site_feature_id' => 4,
                'detail' => '<h4><strong>बंडल ऑफर</strong></h4><p>कई उत्पादों पर</p>',
                'lang' => 'hi'
            ],



            [
                'site_feature_id' => 1,
                'detail' => '<h4><strong>Expédition rapide</strong></h4><p>Avec une courte période de temps</p>',
                'lang' => 'fr'
            ],
            [
                'site_feature_id' => 2,
                'detail' => '<h4><strong>Transaction sécurisée</strong></h4><p>Commander en toute sécurité</p>',
                'lang' => 'fr'
            ],
            [
                'site_feature_id' => 3,
                'detail' => '<h4><strong>Assistance 24/7</strong></h4><p>Prêt à prendre des appels</p>',
                'lang' => 'fr'
            ],
            [
                'site_feature_id' => 4,
                'detail' => '<h4><strong>Offre groupée</strong></h4><p>Sur de nombreux produits</p>',
                'lang' => 'fr'
            ],



            [
                "site_feature_id" => 1,
                'detail' => '<h4><strong>الشحن السريع </h4><p>بفترة زمنية قصيرة</p>',
                'lang' => 'ar'
            ],
            [
                "site_feature_id" => 2,
                'detail' => '<h4><strong>معاملة آمنة</strong></h4><p>تسجيل الخروج بأمان</p>',
                'lang' => 'ar'
            ],
            [
                "site_feature_id" => 3,
                'detail' => '<h4><strong>دعم على مدار الساعة طوال أيام الأسبوع</strong></h4><p>جاهز لاستلام المكالمات</p>',
                'lang' => 'ar'
            ],
            [
                "site_feature_id" => 4,
                'detail' => '<h4><strong>عرض الحزمة</strong></h4><p>في العديد من المنتجات</p>',
                'lang' => 'ar'
            ]
        ];


        if (is_null(SiteFeatureLang::first())) {
            foreach ($banners as $i) {
                SiteFeatureLang::create($i);
            }
        }
    }
}
