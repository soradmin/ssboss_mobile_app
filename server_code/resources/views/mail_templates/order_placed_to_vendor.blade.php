@extends('layouts.email_layout')

@section('content')
    <h3 class="mt-15">{{__('lang.your_order', [], $lang)}} #{{ $order->order }}</h3>
    <p class="mb-20">{{__('lang.placed_on', [], $lang)}} {{ $order->created }}</p>

    <table class="mb-10">
        <tr>
            <th class="pb-10">{{__('lang.ship_to', [], $lang)}}</th>
            <th class="pb-10">{{__('lang.order_method', [], $lang)}}</th>
        </tr>

        <tr>
            <td style="width: 50%;">
                <div style="max-width: 300px;">
                    <h5 style="margin-bottom: 5px">{{ $order->address->name }}</h5>
                    <p>{{ $order->formatted_address }}</p>

                    @if($order->user)
                        <p>{{__('lang.email', [], $lang)}}: {{ $order->user->email }}</p>
                    @elseif($order->guest_user)
                        <p>{{__('lang.email', [], $lang)}}: {{ $order->guest_user->email }}</p>
                    @endif

                    <p>{{__('lang.phone', [], $lang)}}: {{ $order->address->phone }}</p>
                </div>
            </td>
            <td style="width: 50%;">{{ $order->order_method }}</td>
        </tr>
    </table><!--table-->


    <table style="background: #eee; border: 1px solid #ddd; border-bottom: none" class="mt-20 main-table border-tr">
        <tr>
            <th>{{__('lang.title', [], $lang)}}</th>
            <th>{{__('lang.quantity', [], $lang)}}</th>
            <th>{{__('lang.price', [], $lang)}}</th>
            <th>{{__('lang.total', [], $lang)}}</th>
        </tr>

        @foreach ($order->ordered_products as $op)
            <tr style="background: #fff">
                <td>
                    <b>{{ $op->product_with_admin->title }}</b>
                    <span class="mt-5 f-9 block">{{ \App\Models\Helper\MailHelper::generatingAttribute($op) }}</span>
                </td>
                <td>{{ $op->quantity }}</td>

                <td>{{ $setting->currency_icon }}{{ $op->selling }}</td>
                <td>{{ $setting->currency_icon }}{{ $op->selling * $op->quantity }}</td>
            </tr>

        @endforeach
    </table><!--table-->

@stop
