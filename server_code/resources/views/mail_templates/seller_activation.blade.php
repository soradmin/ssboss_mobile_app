<div style="max-width: 600px; ">
    {{__('lang.hello', [], $lang)}} <i>{{ $data->receiver }}</i>,
    <h1>{{__('lang.congo', [], $lang)}}</h1>
    <h4>{{__('lang.ac_success', [], $lang)}}</h4>

    <p>{{__('lang.com', ['commission'=> $data->commission ], $lang)}}</p>


    <h4>{{__('lang.can_login', [], $lang)}}</h4>

    <h5 class="mtb-20">
        <a class="btn"
           href="{{ $data->admin_url }}">
            {{__('lang.seller_login', [], $lang)}}
        </a>
    </h5>


    {{__('lang.thank_you', [], $lang)}}

    <h3>{{ $data->store_name  }}</h3>

    <div style="margin-top: 20px; border-top: 1px solid #eee;">
        <p>{{ $data->address }}</p>
        <p>{{__('lang.phone', [], $lang)}}: <a href="tel:{{ $data->phone}}">{{ $data->phone}}</a></p>
    </div>

</div>
