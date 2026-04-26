<?php

namespace App\Http\Controllers;

use App\Models\Helper\ControllerHelper;
use App\Models\Helper\FileHelper;
use App\Models\Helper\Response;
use App\Models\Helper\Utils;
use App\Models\Helper\Validation;
use App\Models\Plugin;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use ZipArchive;

class PluginsController extends ControllerHelper
{
    public function all(Request $request)
    {
        try {
            if ($can = Utils::userCan($this->user, 'setting.edit')) {
                return $can;
            }


            $data = Plugin::get();

            return response()->json(new Response($request->token, $data));


        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }

    public function upload(Request $request)
    {
        try {
            if ($can = Utils::userCan($this->user, 'setting.edit')) {
                return $can;
            }

            $validate = Validation::zip($request);
            if ($validate) {
                return response()->json($validate);
            }

            $file = $request['file'];
            $filename = $file->getClientOriginalName();


            Storage::disk('public')->put($filename, File::get($file));


            $destinationPath = resource_path('plugins');

            if (!file_exists($destinationPath)) {
                mkdir($destinationPath, 0755, true);
            }

            $sourceFile = FileHelper::getUploadPath() . $filename;

            $zip = new ZipArchive();
            $zipFile = $zip->open($sourceFile);
            if ($zipFile === TRUE) {
                $zip->extractTo($destinationPath);
                $zip->close();

                unlink($sourceFile);

                $fileInfo = pathinfo($filename);

                $plugin = Plugin::where('name', $fileInfo['filename'])->first();
                if (!$plugin) {
                    $plugin['name'] = $fileInfo['filename'];
                    $plugin = Plugin::create($plugin);
                }

                return response()->json(new Response($request->token, $plugin));
            }

            return response()->json(Validation::error($request->token));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function delete(Request $request, $id)
    {
        try {

            $lang = $request->header('language');

            if ($can = Utils::userCan($this->user, 'setting.edit')) {
                return $can;
            }


            $ds = DIRECTORY_SEPARATOR;

            $item = Plugin::find($id);


            if (is_null($item)) {
                return response()->json(Validation::nothingFoundLang($lang));
            }

            if ($item->delete()) {
                $file_path = resource_path('plugins') . $ds . $item->name;

                if (\File::exists($file_path)) {



                        $pluginIndex = $file_path . $ds . 'index.json';

                        if (file_exists($pluginIndex)) {

                            $data = file_get_contents($pluginIndex);
                            $pluginData = json_decode($data, true);

                            $migrations = array_reverse($pluginData['migrations']);

                            foreach ($migrations as $i) {
                                $file_path = rtrim($file_path, $ds);
                                $migrationFile = base_path('/resources/plugins/' . $item->name . '/migrations/' . $i . '.php');

                                if (file_exists($migrationFile)) {
                                    include_once $migrationFile;

                                    $migrationName = preg_replace('/^\d{4}_\d{2}_\d{2}_\d{6}_/', '', $i);

                                    $migrationClass = Str::studly(pathinfo($migrationName, PATHINFO_FILENAME));


                                    if (class_exists($migrationClass)) {

                                        $migrationInstance = new $migrationClass;

                                        $migrationInstance->down();

                                        DB::table('migrations')->where('migration', $migrationFile)->delete();

                                    } else {
                                        return response()->json(Validation::error($request->token,
                                            __('lang.mcd')));
                                    }
                                } else {
                                    return response()->json(Validation::error($request->token,
                                        __('lang.fnf', ['path' => $migrationFile], $lang)));
                                }
                            }


                            foreach ($pluginData['delete'] as $i) {
                                $seederPath = base_path('resources/plugins/' . $item->name . '/seeders/' . $i . '.php');

                                if (file_exists($seederPath)) {
                                    require_once $seederPath;

                                    $seederClassName = 'Database\\Seeders\\' . $i;
                                    $seeder = new $seederClassName;
                                    $seeder->run();
                                } else {
                                    return response()->json(Validation::error($request->token,
                                        __('lang.fnf', ['path' => $seederPath], $lang)));
                                }
                            }


                        }

                    Artisan::call('cache:clear');


                    //\File::deleteDirectory($file_path);
                }
            }

            return response()->json(new Response($request->token, true));

        } catch (\Exception $ex) {
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }


    public function activate(Request $request)
    {
        try {
            $lang = $request->header('language');

            if ($can = Utils::userCan($this->user, 'setting.edit')) {
                return $can;
            }

            $validate = Validation::activatePlugin($request);
            if ($validate) {
                return response()->json($validate);
            }

            $ds = DIRECTORY_SEPARATOR;

            $item = Plugin::where('name', $request->name)->first();

            if (is_null($item)) {
                return response()->json(Validation::nothingFoundLang($lang));
            }

            $destinationPath = resource_path('plugins') . $ds . $request->name;

            if (\File::exists($destinationPath)) {

                $pluginIndex = $destinationPath . $ds . 'index.json';

                if (file_exists($pluginIndex)) {

                    $url = env('LICENCE_SERVER') . "/api/ishop-pos/activate/{$request->code}";

                    //$isLocalHost = $request->getHost() === '127.0.0.1';
                    $isLocalHost = false;

                    $body = null;
                    if(!$isLocalHost){
                        $body = Utils::getRequest($url, $request);
                    }

                    if($isLocalHost || ($body->data->public_key && $body->data->secret_key)){


                        $data = file_get_contents($pluginIndex);
                        $pluginData = json_decode($data, true);

                        foreach ($pluginData['migrations'] as $i) {
                            $migrationFile = base_path('/resources/plugins/' . $item->name . '/migrations/' . $i . '.php');

                            if (file_exists($migrationFile)) {
                                include_once $migrationFile;

                                $migrationName = preg_replace('/^\d{4}_\d{2}_\d{2}_\d{6}_/', '', $i);

                                $migrationClass = Str::studly(pathinfo($migrationName, PATHINFO_FILENAME));


                                if (class_exists($migrationClass)) {

                                    $migrationInstance = new $migrationClass;

                                    $migrationInstance->up();


                                } else {
                                    return response()->json(Validation::error($request->token,
                                        __('lang.mcd')));
                                }
                            } else {
                                return response()->json(Validation::error($request->token,
                                    __('lang.fnf', ['path' => $migrationFile], $lang)));
                            }
                        }

                        foreach ($pluginData['seeders'] as $i) {
                            $seederPath = base_path('resources/plugins/' . $request->name . '/seeders/' . $i . '.php');

                            if (file_exists($seederPath)) {
                                require_once $seederPath;

                                $seederClassName = 'Database\\Seeders\\' . $i;
                                $seeder = new $seederClassName;
                                $seeder->run();
                            } else {
                                return response()->json(Validation::error($request->token,
                                    __('lang.fnf', ['path' => $seederPath], $lang)));
                            }
                        }

                        if(!$isLocalHost){
                            Plugin::where('id', $item->id)->update([
                                'active' => true,
                                'public_key' => $body->data->public_key,
                                'encrypt_key'=> $body->data->encrypt_key,
                                'encrypt_iv'=> $body->data->encrypt_iv,
                                'secret_key'=> $body->data->secret_key
                            ]);
                        }



                        return response()->json(new Response($request->token, true));

                    }


                }
            }

            return response()->json(Validation::error($request->token));

        } catch (\Exception $ex) {

            DB::table('orders')->where('created_at', '0000-00-00 00:00:00')
                ->update(['created_at' => now()]);
            return response()->json(Validation::error($request->token, $ex->getMessage()));
        }
    }
}
