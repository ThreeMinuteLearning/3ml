module Drawer exposing (DrawerType(..), view)

import Html exposing (Html, div, h1, img, input, li, p, text, ul)
import Html.Attributes exposing (checked, class, href, id, src, type_, width)
import Html.Events exposing (onCheck, onClick)


type DrawerType
    = Connect
    | Question
    | Summarise
    | Clarify


drawerToString : DrawerType -> String
drawerToString dt =
    case dt of
        Connect ->
            "Connect"

        Question ->
            "Question"

        Summarise ->
            "Summarise"

        Clarify ->
            " Clarify"


view : Maybe DrawerType -> (DrawerType -> msg) -> Html msg
view showDrawer toggleDrawer =
    let
        currentDrawer =
            Maybe.withDefault Connect showDrawer

        listItem s =
            li [] [ text s ]

        mkList is =
            List.map listItem is
                |> ul []

        drawerHeader =
            div [ class "panelheader" ]
                [ img [ src ("img/" ++ hdrImage), width 25 ] []
                , h1 []
                    [ text (drawerToString currentDrawer)
                    ]
                , Html.a [ href "#", class "closebutton", onClick (toggleDrawer currentDrawer) ]
                    [ img [ src "img/closeblack.png" ] [] ]
                ]

        ( content, hdrImage, panelStyle ) =
            case currentDrawer of
                Connect ->
                    ( [ mkList
                            [ "Do I know something about this already?"
                            , "Has something like this ever happened to me?"
                            , "Have I read about something like this?"
                            , "What does this remind me of in the real world?"
                            ]
                      ]
                    , "connectblack.png"
                    , "connectpanel"
                    )

                Summarise ->
                    ( [ p [] [ text "We want one sentence on what this story is all about." ]
                      , p [] [ text "It doesn't have to be your own words. If there's a sentence in the story that does the job, copy and paste it. Here's what to do if there isn't:" ]
                      , mkList
                            [ "Skim the story fast, looking for good words or phrases."
                            , "Write them down."
                            , "Make a sentence by putting the words together with words of your own."
                            , "Read your sentence aloud. If it doesn't make sense, change it to make it better."
                            , "Take a last look at the story to see if you've missed any important point."
                            ]
                      ]
                    , "summariseblack.png"
                    , "summarisepanel"
                    )

                Question ->
                    ( [ p [] [ text "Here are a few questions you could ask when you're reading. Feel free to think up more of your own." ]
                      , mkList
                            [ "What does that sentence mean?"
                            , "Does this part make sense to me?"
                            , "How does the writer know that?"
                            , "Is that fact or opinion?"
                            , "How did they do that?"
                            , "Why did they do that?"
                            , "What if they had done it this way instead?"
                            , "What question is this person trying to answer?"
                            , "What happens next?"
                            ]
                      ]
                    , "questionblack.png"
                    , "questionpanel"
                    )

                Clarify ->
                    ( [ p [] [ text "Try to figure out what the word means using these methods:" ]
                      , mkList
                            [ "Read a line or two around the word, looking for clues."
                            , "Look for parts of words or whole words in the unknown word."
                            , "Imagine the word isn't there and try another word or words in its place."
                            ]
                      ]
                    , "clarifyblack.png"
                    , "clarifypanel"
                    )
    in
    div []
        [ input
            [ type_ "checkbox"
            , id "toggle-drawer"
            , onCheck (\_ -> toggleDrawer currentDrawer)
            , checked (showDrawer /= Nothing)
            ]
            []
        , div [ id "drawer", class panelStyle ]
            [ drawerHeader
            , div [ id "drawercontent" ] content
            ]
        ]
