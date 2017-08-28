port module Auth.API exposing (main)

import Json.Decode
import Json.Decode.Pipeline exposing (decode, required)
import Serverless
import Serverless.Conn exposing (..)
import Serverless.JWT
import Serverless.Plug as Plug exposing (Plug, plug)


main : Serverless.Program Config Model () () ()
main =
    Serverless.httpApi
        { initialModel = Model ""
        , parseRoute = Serverless.noRoutes
        , update = Serverless.noSideEffects
        , interop = Serverless.noInterop
        , requestPort = requestPort
        , responsePort = responsePort

        -- `Plug.apply` transforms the connection by passing it through each plug
        -- in a pipeline. After the pipeline is processed, the conn may already
        -- be in a "sent" state, so we use `mapUnsent` to conditionally apply
        -- the final responder.
        --
        -- Even if we didn't use `mapUnsent`, no harm could be done, as a sent
        -- conn is immutable.
        , endpoint =
            Plug.apply pipeline >> mapUnsent endpoint

        -- Some middleware may provide a configuration decoder.
        , configDecoder =
            decode Config
                |> required "auth" Serverless.JWT.configDecoder
        }


{-| Stores middleware configuration.
-}
type alias Config =
    { auth : Serverless.JWT.Config }


{-| Store the decoded payload in the model for later use.
-}
type alias Model =
    { payload : String }


pipeline : Plug Config Model () ()
pipeline =
    Plug.pipeline
        |> plug
            (Serverless.JWT.auth
                .auth
                Json.Decode.string
                (\payload model -> { model | payload = payload })
            )


endpoint : Conn Config Model () () -> ( Conn Config Model () (), Cmd () )
endpoint conn =
    respond
        ( 200
        , textBody (conn |> model |> .payload)
        )
        conn


port requestPort : Serverless.RequestPort msg


port responsePort : Serverless.ResponsePort msg
