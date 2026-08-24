<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class AddPhoneAuthFieldsToUsersTable extends Migration
{
    public function up()
    {
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'password_issued_at')) {
                $table->timestamp('password_issued_at')->nullable()->after('password');
            }
            if (!Schema::hasColumn('users', 'otp_sent_at')) {
                $table->timestamp('otp_sent_at')->nullable()->after('code');
            }
        });

        // Уникальный индекс по phone (nullable unique в MySQL допускает несколько NULL)
        Schema::table('users', function (Blueprint $table) {
            try {
                $table->unique('phone');
            } catch (\Throwable $e) {
                // индекс уже может существовать
            }
        });
    }

    public function down()
    {
        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'password_issued_at')) {
                $table->dropColumn('password_issued_at');
            }
            if (Schema::hasColumn('users', 'otp_sent_at')) {
                $table->dropColumn('otp_sent_at');
            }
            try {
                $table->dropUnique(['phone']);
            } catch (\Throwable $e) {
            }
        });
    }
}
