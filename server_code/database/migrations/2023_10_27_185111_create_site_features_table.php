<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateSiteFeaturesTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('site_features', function (Blueprint $table) {
            $table->increments('id');
            $table->timestamps();

            $table->string('image')->default(Config::get('constants.media.DEFAULT_IMAGE'));
            $table->integer('status')->default(Config::get('constants.status.PUBLIC'));

            $table->string('detail')->nullable();


        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('site_features');
    }
}
