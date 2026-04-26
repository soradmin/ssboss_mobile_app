<html>
<head>

    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <style>
        * {
            box-sizing: border-box;
        }

        body,
        html {
            margin: 0;
            padding: 0;
            border: 0;
            font-size: 100%;
            vertical-align: baseline;
            min-height: 100%;
            max-width: 100%;
            box-sizing: border-box;
        }

        * {
            font-family: Hind, DejaVu Sans, sans-serif;
        }

        body {
            font-size: 14px;
            font-weight: 400;
            color: #444;
        }

        h1, h2, h3, h4, h5, h6, p, ul, span, li, input, button {
            margin: 0;
            padding: 0;
            line-height: 1.4;
            box-sizing: border-box;
        }

        span {
            line-height: inherit;
        }

        h1, h2, h3, h4, h5, h6 {
            font-weight: inherit;
        }

        p {
            line-height: 1.8;
            font-size: 1em;
            font-weight: 400;
            color: #112211;
            display: flex;
        }

        h1 {
            font-size: 3.5em;
        }

        h2 {
            font-size: 2.5em;
        }

        h3 {
            font-size: 1.8em;
        }

        h4 {
            font-size: 1.3em;
        }

        h5 {
            font-size: 1.1em;
        }

        h6 {
            font-size: .95em;
            letter-spacing: 1px;
            line-height: 1.6;
        }

        strong {
            font-weight: 700;
        }

        img {
            width: 100%;
            height: auto;
            object-fit: cover;
        }

        li {
            display: block;
            list-style: none;
            font-size: 1em;
        }

        i, span {
            display: inline-block;
        }

        b {
            display: inline-block;
            font-weight: 500;
        }

        .p-30 {
            padding: 30px;
        }


        table {
            width: 100%;
            font-family: inherit;
        }

        table tr {
            vertical-align: top;
        }

        table td {
            font-family: inherit;
        }

        table th {
            font-family: inherit;
            text-align: left;
        }

        .table-c tr th {
            background: #486FF0;
            color: #fff;
            text-align: left;
            font-size: .9em;
            font-weight: 400;
            padding: 10px;
        }

        .border-tr tr td {
            padding: 10px;
            border-bottom: 1px solid #eee;
        }

        .border-tr tr:last-child td {
            border-bottom: none;
        }

        .table-c tr td {
            padding: 5px 10px;
        }

        .td-right-align tr td {
            text-align: right;
            padding: 5px 0;
        }

        .main-table tr td{
            padding: 15px 10px;
        }

        .mt-10 {
            margin-top: 10px;
        }

        .mb-5 {
            margin-bottom: 5px;
        }

        .mb-10 {
            margin-bottom: 10px;
        }

        .mb-20 {
            margin-bottom: 20px;
        }

        .ml-10 {
            margin-left: 10px;
        }

        .block {
            display: block;
        }

        .mt-5 {
            margin-top: 5px;
        }

        .f-9{
            font-size: .9em;
            color: #666
        }

        .left-head{
            max-width: 300px;
            line-height: 2;
        }

        .lh{
            line-height: 1.8;
        }


    </style>
</head>
<body style="line-height: 1.7; padding: 30px; direction: {{ $lang == 'ar' ? 'rtl' : 'ltl' }};" >
<table class="mb-20">
    <tr>
        <td style="width: 50%;" class="lh">

                <img style="height: 25px; width: auto; padding-bottom: 10px"
                     src="data:image/png;base64,{{$setting->logo_base64}}">
                <h4 class="mt-10 mb-10">{{ $setting->store_name }}</h4>
                <p style="line-height: 2"> {{$setting->address}}</p>
                <p>{{__('lang.phone', [], $lang)}}: {{ $setting->phone }}</p>

        </td>
        <td>
            <h3 class="mb-10 ml-10">{{__('lang.inv', [], $lang)}}</h3>
            <table style="max-width: 400px;">
                <tr>
                    <td>{{__('lang.order', [], $lang)}}</td>
                    <td>#{{ $order->order }}</td>
                </tr>
                <tr>
                    <td>{{__('lang.order_date', [], $lang)}}</td>
                    <td>{{ $order->created }}</td>
                </tr>
                <tr>
                    <td>{{__('lang.order_amount', [], $lang)}}</td>
                    <td>{{ $setting->currency_icon }}{{ $order->calculated_price['total_price'] }}</td>
                </tr>
            </table>
        </td>
    </tr>
</table>

<table class="mb-20 table-c">
    <tr>
        <th style="text-align: left;" >{{__('lang.ship_to', [], $lang)}}</th>
        <th style="text-align: left;">{{__('lang.order_method', [], $lang)}}</th>
    </tr>

    <tr>
        <td style="width: 50%;" class="lh">
            <div style="max-width: 300px;">
                <h5 class="mb-5">{{ $order->address->name }}</h5>
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

<table class="border-tr table-c main-table">
    <tr>
        <th>{{__('lang.title', [], $lang)}}</th>
        <th>{{__('lang.delivery_fee', [], $lang)}}</th>
        <th>{{__('lang.quantity', [], $lang)}}</th>
        <th>{{__('lang.price', [], $lang)}}</th>
        <th>{{__('lang.total', [], $lang)}}</th>
    </tr>

    @foreach ($order->ordered_products as $op)
        <tr>
            <td class="lh" >
                <p style="display: block; ">{{ $op->product->title }}</p>
                <span style="font-size: .9rem; padding-top: 5px;">
                    {{ \App\Models\Helper\MailHelper::generatingAttribute($op) }}
                </span>
            </td>
            <td>
                {{ $setting->currency_icon }}
                {{ \App\Models\Helper\MailHelper::shippingPrice($op->shipping_place, $op->shipping_type) }}
            </td>
            <td>{{ $op->quantity }}</td>

            <td>{{ $setting->currency_icon }}{{ $op->selling }}</td>
            <td>{{ $setting->currency_icon }}{{ $op->selling * $op->quantity }}</td>
        </tr>

    @endforeach
</table><!--table-->

<div style="width: 100%; clear: both; display: block; margin-top: 20px;">
    <table class="border-tr td-right-align" style="margin-left: auto; width: 180px; max-width: 180px;">
        <tr>
            <td style="min-width: 110px">{{__('lang.subtotal', [], $lang)}}</td>
            <td style="min-width: 40px">{{ $setting->currency_icon }}{{ $order->calculated_price['subtotal'] }}</td>
        </tr>
        <tr>
            <td>{{__('lang.shipping_cost', [], $lang)}}</td>

            @if((float) $order->calculated_price['shipping_price'] > 0)
                <td>{{ $setting->currency_icon }}{{ $order->calculated_price['shipping_price'] }}</td>
            @else
                <td>{{__('lang.fre', [], $lang)}}</td>
            @endif


        </tr>

        @if ((int) $order->calculated_price['bundle_offer'] > 0)
            <tr>
                <td>{{__('lang.bundle_offer', [], $lang)}}</td>
                <td>{{ $setting->currency_icon }}{{ $order->calculated_price['bundle_offer'] }}</td>
            </tr>
        @endif

        @if ((int) $order->calculated_price['voucher_price'] > 0)
            <tr>
                <td>{{__('lang.voucher', [], $lang)}}</td>
                <td>{{ $setting->currency_icon }}{{ $order->calculated_price['voucher_price'] }}</td>
            </tr>
        @endif

        @if ((int) $order->calculated_price['tax'] > 0)
            <tr>
                <td>{{__('lang.tax', [], $lang)}}</td>
                <td>{{ $setting->currency_icon }}{{ $order->calculated_price['tax'] }}</td>
            </tr>
        @endif

        <tr>
            <td>{{__('lang.total', [], $lang)}}</td>
            <td>{{ $setting->currency_icon }}{{ $order->calculated_price['total_price'] }}</td>
        </tr>
    </table>
</div>



<div style="width: 100%; clear: both; display: block; padding-top: 100px;">
    <table class="table-c" style="width: 50%;">
        <tr>
            <th>{{__('lang.notes', [], $lang)}}</th>
        </tr>

        <tr>
            <td  class="lh"  style="width: 50%;">
                <p style="padding-bottom: 10px;">
                    {{__('lang.order_number', [], $lang)}}
                </p>
                <p>
                    {{__('lang.question_str', [], $lang)}}: {{ $setting->phone }}
                </p>
            </td>
        </tr>
    </table><!--table-->
</div>



</body>
