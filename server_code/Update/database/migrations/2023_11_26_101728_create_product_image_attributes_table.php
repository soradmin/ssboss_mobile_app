<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateProductImageAttributesTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('product_image_attributes', function (Blueprint $table) {
            $table->increments('id');
            $table->timestamps();


            $table->integer('product_image_id')->unsigned();
            $table->integer('attribute_value_id')->unsigned();

            $table->foreign('attribute_value_id')
                ->references('id')
                ->on('attribute_values');

            $table->foreign('product_image_id')
                ->references('id')
                ->on('product_images');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('product_image_attributes');
    }
}
