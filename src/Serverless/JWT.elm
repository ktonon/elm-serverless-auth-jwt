module Serverless.JWT
    exposing
        ( Config
        , auth
        , configDecoder
        )

{-| Authorization middleware for elm-serverless using JSON Web Tokens.

Examples assume the following:

    import Json.Decode
    import Serverless.Conn as Conn
    import Serverless.Plug as Plug exposing (pipeline, plug)

@docs auth, configDecoder, Config

-}

import Json.Decode exposing (Decoder, map, string)
import Json.Decode.Pipeline exposing (decode, required)
import JsonWebToken as JWT exposing (Alg, DecodeError(..), Secret)
import Serverless.Conn as Conn exposing (Conn, textBody)
import Serverless.Conn.Response exposing (setBody, setStatus)


{-| Authorization configuration.
-}
type Config
    = Config Model


type alias Model =
    { secret : String
    }


{-| Configuration decoder.

    import Json.Decode exposing (decodeString)

    decodeString configDecoder """{ "secret": "foobar" }"""
        |> toString
    --> """Ok (Config { secret = "foobar" })"""

-}
configDecoder : Decoder Config
configDecoder =
    decode Model
        |> required "secret" string
        |> map Config



-- MIDDLEWARE


{-| Authorization middleware.

    pipeline
        |> plug
            (Serverless.JWT.auth
                -- Store the JWT secret in your config and
                -- tell the middleware how to get it
                .authJWT
                -- Define the structure of the JWT payload
                -- using a JSON decoder
                Json.Decode.string
                -- Store the decoded payload in your model
                (\payload model -> { model | payload = payload })
            )
        |> Plug.size
    --> 1

-}
auth :
    (config -> Config)
    -> Decoder payload
    -> (payload -> model -> model)
    -> Conn config model route interop
    -> Conn config model route interop
auth extract decoder updateModel conn =
    case conn |> Conn.config |> extract of
        Config model ->
            auth_ model.secret decoder updateModel conn


auth_ :
    Secret
    -> Decoder payload
    -> (payload -> model -> model)
    -> Conn config model route interop
    -> Conn config model route interop
auth_ secret decoder setPayload conn =
    case Conn.header "authorization" conn of
        Just val ->
            case String.split " " val of
                [ "Bearer", token ] ->
                    case JWT.decode decoder secret token of
                        Ok payload ->
                            Conn.updateModel (setPayload payload) conn

                        Err (InvalidSecret _) ->
                            fail 401 "JWT validation failed" conn

                        Err (DecodeHeaderFailed _ msg) ->
                            fail 401 ("Unsupported header in JWT: " ++ msg) conn

                        Err (DecodePayloadFailed msg) ->
                            fail 400 ("Could not decode JWT payload: " ++ msg) conn

                        Err InvalidToken ->
                            fail 401 "Invalid JWT provided in Authorization header" conn

                _ ->
                    fail 401 "Unsupported Authorization header. Use 'Bearer JSON_WEB_TOKEN'" conn

        Nothing ->
            fail 401 "Authorization header missing" conn


fail :
    Int
    -> String
    -> Conn config model route interop
    -> Conn config model route interop
fail code msg =
    Conn.updateResponse (setStatus code >> setBody (textBody msg))
        >> Conn.toSent
