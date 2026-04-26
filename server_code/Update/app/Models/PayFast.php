<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PayFast extends Model
{
    use HasFactory;


    public static function generateSignature($data, $passPhrase = null) {
        // Create parameter string
        $pfOutput = '';
        foreach( $data as $key => $val ) {
            if($val !== '') {
                $pfOutput .= $key .'='. urlencode( trim( $val ) ) .'&';
            }
        }
        // Remove last ampersand
        $getString = substr( $pfOutput, 0, -1 );
        if( $passPhrase !== null ) {
            $getString .= '&passphrase='. urlencode( trim( $passPhrase ) );
        }
        return md5( $getString );
    }

    public static function pfValidSignature( $pfData, $pfParamString, $pfPassphrase = null ) {
        // Calculate security signature
        if($pfPassphrase === null) {
            $tempParamString = $pfParamString;
        } else {
            $tempParamString = $pfParamString . 'passphrase=' . urlencode( $pfPassphrase );
        }

        $signature = md5( $tempParamString );
        return ( $pfData['signature'] === $signature );
    }



    public static function pfValidIP() {
        // Variable initialization
        $validHosts = array(
            'www.payfast.co.za',
            'sandbox.payfast.co.za',
            'w1w.payfast.co.za',
            'w2w.payfast.co.za',
        );

        $validIps = [];

        foreach( $validHosts as $pfHostname ) {
            $ips = gethostbynamel( $pfHostname );

            if( $ips !== false )
                $validIps = array_merge( $validIps, $ips );
        }

        // Remove duplicates
        $validIps = array_unique( $validIps );


        if (isset($_SERVER['HTTP_REFERER'])) {
            $url = parse_url($_SERVER['HTTP_REFERER']);

            if (isset($url['host'])) {
                // Get the IP address of the referrer
                $referrerIp = gethostbyname($url['host']);

                if( in_array( $referrerIp, $validIps, true ) ) {
                    return true;
                }
            }
        }


        return false;
    }

    public static function pfValidPaymentData( $cartTotal, $pfData ) {
        return !(abs((float)$cartTotal - (float)$pfData['amount_gross']) > 0.01);
    }

    public static function pfValidServerConfirmation( $pfParamString, $pfHost = 'sandbox.payfast.co.za', $pfProxy = null ) {
        // Use cURL (if available)
        if( in_array( 'curl', get_loaded_extensions(), true ) ) {
            // Variable initialization
            $url = $pfHost .'/eng/query/validate';

            // Create default cURL object
            $ch = curl_init();

            // Set cURL options - Use curl_setopt for greater PHP compatibility
            // Base settings
            curl_setopt( $ch, CURLOPT_USERAGENT, NULL );  // Set user agent
            curl_setopt( $ch, CURLOPT_RETURNTRANSFER, true );      // Return output as string rather than outputting it
            curl_setopt( $ch, CURLOPT_HEADER, false );             // Don't include header in output
            curl_setopt( $ch, CURLOPT_SSL_VERIFYHOST, 2 );
            curl_setopt( $ch, CURLOPT_SSL_VERIFYPEER, true );

            // Standard settings
            curl_setopt( $ch, CURLOPT_URL, $url );
            curl_setopt( $ch, CURLOPT_POST, true );
            curl_setopt( $ch, CURLOPT_POSTFIELDS, $pfParamString );
            if( !empty( $pfProxy ) )
                curl_setopt( $ch, CURLOPT_PROXY, $pfProxy );

            // Execute cURL
            $response = curl_exec( $ch );
            curl_close( $ch );
            if ($response === 'VALID') {
                return true;
            }
        }
        return false;
    }



    public static function getPayFastForm( $payment, $order, $re, $price ) {
        $data = array(
            // Merchant details
            'merchant_id' => $payment->payfast_merchant_id,
            'merchant_key' => $payment->payfast_merchant_key,
            'return_url' => config('env.url.CLIENT_BASE_URL') . '/payfast/return/' . $order->id,
            'cancel_url' => config('env.url.CLIENT_BASE_URL') . '/payfast/cancel/' . $order->id,
            'notify_url' => config('env.url.APP_URL') .  '/api/v1/order/payfast-notify',
            // Buyer details
            'name_first' => $re['name'],
            'name_last'  => '',
            'email_address'=> $re['email'] ,
            // Transaction details
            'm_payment_id' => $order->id, //Unique payment ID to pass through to notify_url
            'amount' => number_format( sprintf( '%.2f', $price), 2, '.', '' ),
            'item_name' => 'Order#' . $order->id,
        );

        $signature = PayFast::generateSignature($data, $payment->payfast_passphrase);
        $data['signature'] = $signature;

        $pfHost = $payment->payfast_base_url . '/eng/process';
        //$pfHost = PAYFAST_SANDBOX_MODE ? 'sandbox.payfast.co.za' : 'www.payfast.co.za';
        $htmlForm = '<form action="'.$pfHost.'" method="post" id="frmPayment">';
        foreach($data as $name=> $value)
        {
            $htmlForm .= '<input name="'.$name.'" type="hidden" value=\''.$value.'\' />';
        }
        $htmlForm .= '<input type="submit" value="Pay Now" style="opacity: 0;max-width: 0;overflow: hidden;"/></form>';

        return $htmlForm;
    }

}
