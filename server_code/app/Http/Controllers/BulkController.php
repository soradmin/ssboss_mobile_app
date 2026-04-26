<?php

namespace App\Http\Controllers;

use App\Exports\ProductsExport;
use App\Imports\ProductsImport;
use App\Models\Helper\ControllerHelper;
use App\Models\Helper\Response;
use App\Models\Helper\Utils;
use App\Models\Helper\Validation;
use App\Models\Product;
use Illuminate\Http\Request;


class BulkController extends ControllerHelper
{

    public function exportData(Request $request)
    {
        try {

            if ($can = Utils::userCan($this->user, 'bulk_upload.view')) {
                return $can;
            }

            $lang = $request->header('language');

            $filename = 'products-'. date('Y-m-d-H_i_s') .'.xlsx';

            $products = new ProductsExport($lang);

           return \Excel::download($products, $filename, \Maatwebsite\Excel\Excel::XLSX, [
                'Access-Control-Expose-Headers'=> 'Content-Disposition',
                'Content-Disposition' => 'attachment; filename="' . $filename .'"',
            ]);

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function importData(Request $request)
    {
        try {
            if ($can = Utils::userCan($this->user, 'bulk_upload.edit')) {
                return $can;
            }

            $lang = $request->header('language');

            $file = $request['file'];

            $products = new ProductsImport($lang);

            \Excel::import($products, $file);

            return response()->json(new Response($request->token, true));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }
}
