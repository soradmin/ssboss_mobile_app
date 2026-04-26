<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreatePluginTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('plugins', function (Blueprint $table) {
            $table->increments('id');
            $table->timestamps();

            $table->string('name')->nullable();
            $table->text('public_key')->nullable();
            $table->text('encrypt_key')->nullable();
            $table->text('encrypt_iv')->nullable();
            $table->text('secret_key')->nullable();

            $table->boolean('active')->nullable()->default(false);
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('plugins');
    }
}
