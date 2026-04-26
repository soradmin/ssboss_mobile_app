<?php

namespace Database\Seeders;

use App\Models\PosSetting;
use App\Models\PosSettingLang;
use Illuminate\Database\Seeder;

class PosSettingLangSeeder extends Seeder
{
    /**
     * Run the database seeds.
     *
     * @return void
     */
    public function run()
    {
        $items = [
            [
                'pos_setting_id' => 1,
                'address' => '13. Cadde. 47 W 13th St, New York, NY 10011, ABD',
                'header_text' => 'Merkezi KDV kayıt no: 000333-54545454',
                'footer_text' => '**Bu challan a ilişkin KDV, merkezi kayıt yoluyla ödenir. ISHOP tan alışveriş yaptığınız için teşekkür ederiz. Soru, öneri ve şikayetleriniz için lütfen 12345(09.00 - 18.00) numaralı telefonu arayın.',
                'lang' => 'tr',
            ],

            [
                'pos_setting_id' => 1,
                'address' => 'شارع 13. 47 دبليو شارع 13، نيويورك، نيويورك 10011، الولايات المتحدة الأمريكية',
                'header_text' => 'رقم تسجيل ضريبة القيمة المضافة المركزي: 000333-54545454',
                'footer_text' => '** ضريبة القيمة المضافة مقابل هذا التحدي واجبة الدفع من خلال التسجيل المركزي. شكرًا لك على التسوق مع ISHOP. لأية استفسارات أو اقتراحات أو شكاوى برجاء الاتصال على 12345 (9.00 صباحًا - 6.00 مساءً)',
                'lang' => 'ar',
            ],


            [
                'pos_setting_id' => 1,
                'address' => '13ème rue. 47 W 13th St, New York, NY 10011, États-Unis',
                'header_text' => 'N° TVA intracommunautaire : 000333-54545454',
                'footer_text' => '**La TVA sur ce challan est payable via l enregistrement central. Merci pour vos achats avec ISHOP. Pour toute question, suggestion ou réclamation, veuillez appeler le 12345 (9h00 - 18h00)',
                'lang' => 'fr',
            ],

            [
                'pos_setting_id' => 1,
                'address' => '13वीं स्ट्रीट. 47 डब्ल्यू 13वीं स्ट्रीट, न्यूयॉर्क, एनवाई 10011, यूएसए',
                'header_text' => 'सेंट्रल वैट पंजीकरण संख्या: 000333-54545454',
                'footer_text' => '**इस चालान के विरुद्ध वैट केंद्रीय पंजीकरण के माध्यम से देय है। आईएसएचओपी के साथ आपकी खरीदारी के लिए धन्यवाद। किसी भी प्रश्न, सुझाव या शिकायत के लिए कृपया 12345 (सुबह 9.00 बजे - शाम 6.00 बजे) पर कॉल करें।',
                'lang' => 'hi',
            ]
        ];



        $tr1 = PosSetting::where('id', 1)->first();


        if (!PosSettingLang::first() && $tr1) {
            foreach ($items as $i) {
                PosSettingLang::create($i);
            }
        }
    }
}
