<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateCustomScriptTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('custom_scripts', function (Blueprint $table) {
            $table->increments('id');

            $table->string('route_pattern')->nullable();

            $table->boolean('header_script')->default(false)->nullable();
            $table->text('header_script_code')->nullable();

            $table->boolean('body_script')->default(false)->nullable();
            $table->text('body_script_code')->nullable();

            $table->integer('status')->default(Config::get('constants.status.PRIVATE'));

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('custom_scripts');
    }
}
