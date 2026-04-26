<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Config;

class UpdateAdminTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('admins', function (Blueprint $table) {
            $table->string('username')->nullable()->change();
            $table->boolean('active')->nullable()->default(false);
            $table->boolean('verified')->nullable()->default(false);
            $table->boolean('viewed')->default(false);
        });



    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('admins', function (Blueprint $table) {
            $table->dropColumn('username');
            $table->dropColumn('verified');
            $table->dropColumn('active');
            $table->dropColumn('viewed');
        });
    }
}
