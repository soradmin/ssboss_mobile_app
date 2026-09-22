<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

class CreateUserFcmTokensTable extends Migration
{
    public function up()
    {
        if (!Schema::hasTable('user_fcm_tokens')) {
            Schema::create('user_fcm_tokens', function (Blueprint $table) {
                $table->id();
                $table->unsignedBigInteger('user_id')->index();
                $table->string('fcm_token', 512)->unique();
                $table->string('device_type', 20)->nullable()->index();
                $table->timestamps();

                $table->foreign('user_id')
                    ->references('id')
                    ->on('users')
                    ->onDelete('cascade');
            });
        }

        // Переносим уже сохранённые токены из users.fcm_token
        if (Schema::hasColumn('users', 'fcm_token') && Schema::hasTable('user_fcm_tokens')) {
            $rows = DB::table('users')
                ->whereNotNull('fcm_token')
                ->where('fcm_token', '!=', '')
                ->get(['id', 'fcm_token']);

            $now = now();
            foreach ($rows as $row) {
                $exists = DB::table('user_fcm_tokens')
                    ->where('fcm_token', $row->fcm_token)
                    ->exists();
                if ($exists) {
                    continue;
                }
                DB::table('user_fcm_tokens')->insert([
                    'user_id' => $row->id,
                    'fcm_token' => $row->fcm_token,
                    'device_type' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }
    }

    public function down()
    {
        Schema::dropIfExists('user_fcm_tokens');
    }
}
