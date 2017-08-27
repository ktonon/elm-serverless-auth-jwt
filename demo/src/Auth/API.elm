port module Auth.API exposing (main)

import Json.Decode
import Json.Decode.Pipeline exposing (decode, required)
import Serverless
import Serverless.Conn exposing (..)
import Serverless.JWT
import Serverless.Plug as Plug exposing (Plug, plug)


{-| Pipelines demo.

Pipelines are sequences of functions which transform the connection. They are
ideal for building middleware.

-}
main : Serverless.Program Config () () () ()
main =
    Serverless.httpApi
        { initialModel = ()
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
            Plug.apply pipeline
                >> mapUnsent (respond ( 200, textBody "Pipeline applied" ))

        -- Some middleware may provide a configuration decoder.
        , configDecoder =
            decode Config
                |> required "auth" Serverless.JWT.configDecoder
        }


{-| Stores middleware configuration.
-}
type alias Config =
    { auth : Serverless.JWT.Config }


pipeline : Plug Config () () ()
pipeline =
    Plug.pipeline
        |> plug (Serverless.JWT.auth .auth Json.Decode.string (\payload model -> model))


port requestPort : Serverless.RequestPort msg


port responsePort : Serverless.ResponsePort msg
