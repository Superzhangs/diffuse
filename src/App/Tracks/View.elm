module Tracks.View exposing (entry)

import Authentication.Demo
import Color
import DnD
import Json.Decode as Decode
import InfiniteList
import List.Extra as List
import Maybe.Extra as Maybe
import Mouse
import Navigation.Types exposing (..)
import Navigation.View as Navigation
import Playlists.Types exposing (Playlist)
import Playlists.Utils exposing (..)
import Queue.Types
import Routing.Types
import Sources.Types exposing (IsProcessing, Source)
import Tracks.Types exposing (..)
import Types as TopLevel exposing (Msg(..))


-- Elements

import Element exposing (..)
import Element.Attributes exposing (..)
import Element.Events exposing (..)
import Element.Events.Ext exposing (..)
import Element.Ext exposing (..)
import Element.Input as Input
import Element.Keyed as Keyed
import Element.Types exposing (..)
import Layouts exposing (..)
import Variables exposing (colorDerivatives, colors, scaled, scaledStr)
import Variations exposing (Variations(..))


-- Html

import Html exposing (Html)
import Html.Attributes
import Html.Events
import Html.Keyed
import Html.Lazy


-- Icons

import Material.Icons.Action
import Material.Icons.Av
import Material.Icons.Content
import Material.Icons.Editor
import Material.Icons.Image
import Material.Icons.Navigation


-- Styles

import Styles exposing (Styles(..))
import Tracks.Styles exposing (Styles(..), iconColor, trackHeight)


-- 🍯


entry : TopLevel.Model -> Node
entry model =
    column
        (Tracks Container)
        [ height fill ]
        [ lazy3
            navigation
            ( model.tracks.searchTerm
            , model.tracks.searchCounter
            )
            model.tracks.favouritesOnly
            model.tracks.selectedPlaylist
        , content
            model
        ]



-- Views


navigation : ( Maybe String, Int ) -> Bool -> Maybe Playlist -> Node
navigation ( searchTerm, searchCounter ) favouritesOnly maybeSelectedPlaylist =
    row
        (Tracks Tracks.Styles.Navigation)
        []
        [ -----------------------------------
          -- Part 1
          -----------------------------------
          within
            [ -- Search icon
              --
              row
                Zed
                [ height fill
                , spacing (scaled -8)
                , verticalCenter
                ]
                [ el
                    WithoutLineHeight
                    [ moveRight 2, paddingLeft (scaled -3) ]
                    (16
                        |> Material.Icons.Action.search iconColor
                        |> html
                    )
                ]

            -- Other icons
            --
            , row
                Zed
                [ alignRight
                , height fill
                , spacing (scaled -8)
                , verticalCenter
                , width fill
                ]
                [ -- 1.
                  --
                  if Maybe.isJust searchTerm then
                    el
                        (Tracks ClickableAction)
                        [ attribute "title" "Clear search"
                        , onClickStop (TracksMsg Tracks.Types.ClearSearch)
                        ]
                        (16
                            |> Material.Icons.Content.clear iconColor
                            |> html
                        )
                  else if Maybe.isJust maybeSelectedPlaylist then
                    el
                        (Tracks ClickableAction)
                        [ attribute "title" "Deactivate playlist"

                        --
                        , maybeSelectedPlaylist
                            |> Maybe.map (TogglePlaylist >> TracksMsg)
                            |> Maybe.withDefault NoOp
                            |> onClickStop
                        ]
                        (16
                            |> Material.Icons.Content.clear colors.base08
                            |> html
                        )
                  else
                    empty

                -- 2.
                --
                , el
                    (Tracks ClickableAction)
                    [ attribute "title" "Toggle favourites-only"
                    , onClickStop (TracksMsg ToggleFavouritesOnly)
                    , paddingRight (scaled 1)
                    ]
                    (case favouritesOnly of
                        True ->
                            html (Material.Icons.Action.favorite colors.base08 16)

                        False ->
                            html (Material.Icons.Action.favorite_border iconColor 16)
                    )
                ]
            ]
            (Input.text
                (Tracks Tracks.Styles.Search)
                [ inputBottomPadding
                , inputTopPadding
                , onBlur (TracksMsg DebouncedSearch)
                , onEnterKey (TracksMsg <| Tracks.Types.Search searchTerm)
                , paddingLeft (scaled -3 + 16 + scaled -3)
                , width fill
                ]
                { onChange = TracksMsg << SetSearchTerm
                , value = Maybe.withDefault "" searchTerm
                , label =
                    Input.placeholder
                        { text = "Search"
                        , label = Input.hiddenLabel "search"
                        }
                , options =
                    [ Input.textKey (toString searchCounter) ]
                }
            )

        -----------------------------------
        -- Part 2
        -----------------------------------
        , Navigation.insideCustom
            [ ( Icon Material.Icons.Editor.format_list_numbered
              , Label (Hidden "Playlists")
              , Playlists.Types.Index
                    |> Routing.Types.Playlists
                    |> Routing.Types.GoToPage
                    |> RoutingMsg
              )
            , ( Icon Material.Icons.Action.event_seat
              , Label (Hidden "Queue")
              , Queue.Types.Index
                    |> Routing.Types.Queue
                    |> Routing.Types.GoToPage
                    |> RoutingMsg
              )
            , ( Icon Material.Icons.Av.equalizer
              , Label (Hidden "Equalizer")
              , Routing.Types.Equalizer
                    |> Routing.Types.GoToPage
                    |> RoutingMsg
              )
            ]
        ]


content : TopLevel.Model -> Node
content model =
    el
        Zed
        [ attribute "data-favourites-only" (boolToAttr model.tracks.favouritesOnly)
        , clip
        , height fill
        ]
        (if List.isEmpty model.tracks.collection.harvested then
            lazySpread3
                noTracksFound
                model.sources.collection
                model.sources.isProcessing
                (List.length model.tracks.favourites)
         else
            case Maybe.map .autoGenerated model.tracks.selectedPlaylist of
                Just False ->
                    lazySpread3
                        playlistTable
                        model.tracks.collection.harvested
                        model.tracks.dnd
                        model.isTouchDevice

                _ ->
                    lazySpread3
                        defaultTable
                        model.tracks.collection.harvested
                        ( model.tracks.sortBy
                        , model.tracks.sortDirection
                        )
                        ( model.tracks.infiniteList
                        , model.isTouchDevice
                        , model.screenHeight
                        )
        )



-- Content messages


msgProcessing : Node
msgProcessing =
    el (Tracks Placeholder) [] (text "Processing Tracks")


msgNoSources : Int -> Node
msgNoSources amountOfFavourites =
    let
        btnWithIcon icon btnStyles lbl =
            el
                btnStyles
                [ paddingXY (scaled -5) (scaled -6) ]
                (row
                    Zed
                    [ spacing (scaled -8) ]
                    [ el
                        WithoutLineHeight
                        [ moveDown 1, verticalCenter ]
                        (html icon)
                    , text lbl
                    ]
                )
    in
        row
            Zed
            [ spacing (scaled -2) ]
            [ "Add some music"
                |> btnWithIcon (Material.Icons.Content.add colors.base08 15) ImportantButton
                |> link "/sources"
                |> el Zed
                    [ onClickPrevent
                        (Sources.Types.New
                            |> Routing.Types.Sources
                            |> Routing.Types.GoToPage
                            |> RoutingMsg
                        )
                    ]

            --
            , if amountOfFavourites == 0 then
                "Insert demo"
                    |> btnWithIcon (Material.Icons.Image.music_note colors.base0B 15) Button
                    |> el Zed
                        [ onClickPrevent
                            (TopLevel.InsertDemoContent Authentication.Demo.data)
                        ]
              else
                empty
            ]


msgNoTracks : Node
msgNoTracks =
    el (Tracks Placeholder) [] (text "No tracks found")



-- Content views, Part 1


noTracksFound : List Source -> IsProcessing -> Int -> Node
noTracksFound sources isProcessing amountOfFavourites =
    within
        [ logoBackdrop
        , el
            Zed
            [ center, verticalCenter ]
            (case isProcessing of
                Just _ ->
                    msgProcessing

                Nothing ->
                    case List.length sources of
                        0 ->
                            msgNoSources amountOfFavourites

                        _ ->
                            msgNoTracks
            )
        ]
        (el
            Zed
            [ height fill, width fill ]
            empty
        )



-- Content views, Part 2.1


type alias InfiniteListDeps =
    ( InfiniteList.Model, Bool, Int )


defaultTable : List IdentifiedTrack -> ( SortBy, SortDirection ) -> InfiniteListDeps -> Node
defaultTable tracks ( activeSortBy, sortDirection ) ( infiniteList, isTouchDevice, screenHeight ) =
    column
        (Tracks Table)
        (List.append
            (tableAttr)
            [ InfiniteListMsg
                >> TracksMsg
                |> InfiniteList.onScroll
                |> Element.Attributes.toAttr
            ]
        )
        [ defaultTableHeader activeSortBy sortDirection
        , html
            (InfiniteList.view
                (infiniteListConfig isTouchDevice screenHeight defaultTableItem)
                (infiniteList)
                (tracks)
            )
        ]


playlistTable : List IdentifiedTrack -> DnD.Model Int -> Bool -> Node
playlistTable tracks dnd isTouchDevice =
    column
        (Tracks Table)
        (List.append
            (tableAttr)
            (playlistDragMsg
                |> DnD.containerHooks
                |> List.map Element.Attributes.toAttr
            )
        )
        [ playlistTableHeader
        , tracks
            |> List.map (playlistTableItem <| DnD.overSubject dnd)
            |> Html.ol (listAttributes isTouchDevice)
            |> html
        ]


tableAttr : List Attr
tableAttr =
    [ clipX
    , height fill
    , id "tracks"
    , inlineStyle [ ( "border-radius", "3px" ), ( "display", "block" ) ]
    , yScrollbar
    ]


infiniteListConfig :
    Bool
    -> Int
    -> (Int -> Int -> IdentifiedTrack -> Html TopLevel.Msg)
    -> InfiniteList.Config IdentifiedTrack TopLevel.Msg
infiniteListConfig isTouchDevice screenHeight itemView =
    InfiniteList.withCustomContainer
        (infiniteListContainer isTouchDevice)
        (InfiniteList.config
            { itemView = itemView
            , itemHeight = InfiniteList.constantHeight trackHeight
            , containerHeight = screenHeight
            }
        )


infiniteListContainer :
    Bool
    -> List ( String, String )
    -> List (Html TopLevel.Msg)
    -> Html TopLevel.Msg
infiniteListContainer isTouchDevice styles children =
    Html.ol
        (List.append
            [ Html.Attributes.style styles ]
            (listAttributes isTouchDevice)
        )
        children


listAttributes : Bool -> List (Html.Attribute TopLevel.Msg)
listAttributes isTouchDevice =
    if isTouchDevice then
        -- Touch devices
        [ Html.Attributes.class "tracks__table"

        --
        , Html.Events.on "dbltap" playTrack
        , Html.Events.on "tap" toggleFavourite
        , Html.Events.onWithOptions
            "longtap"
            { stopPropagation = True
            , preventDefault = True
            }
            showContextMenuOnTouch
        , Html.Events.onWithOptions
            "touchend"
            { stopPropagation = False
            , preventDefault = True
            }
            (Decode.succeed TopLevel.NoOp)
        ]
    else
        -- Non-Touch devices
        [ Html.Attributes.class "tracks__table"

        --
        , Html.Events.on "dblclick" playTrack
        , Html.Events.on "click" (Decode.oneOf [ toggleFavourite, selectTrack ])
        , Html.Events.onWithOptions
            "contextmenu"
            { stopPropagation = True
            , preventDefault = True
            }
            showContextMenu
        ]



-- Content views, Part 2.2


defaultTableHeader : SortBy -> SortDirection -> Node
defaultTableHeader activeSortBy sortDirection =
    let
        sortIcon =
            (if sortDirection == Desc then
                Material.Icons.Navigation.expand_less
             else
                Material.Icons.Navigation.expand_more
            )
                (Color.rgb 207 207 207)
                15
    in
        row
            (Tracks TableHeader)
            []
            [ tableHeaderColumn "" "4.50%" First Nothing

            --
            , Just Title
                |> tableHeaderColumn "Title" "37.5%" Between
                |> within [ maybeShowSortIcon activeSortBy Title sortIcon ]

            --
            , Just Artist
                |> tableHeaderColumn "Artist" "29.0%" Between
                |> within [ maybeShowSortIcon activeSortBy Artist sortIcon ]

            --
            , Just Album
                |> tableHeaderColumn "Album" "29.0%" Last
                |> within [ maybeShowSortIcon activeSortBy Album sortIcon ]
            ]


playlistTableHeader : Node
playlistTableHeader =
    row
        (Tracks TableHeader)
        []
        [ tableHeaderColumn "" "4.50%" First Nothing
        , tableHeaderColumn "#" "6.00%" Between Nothing
        , tableHeaderColumn "Title" "36.5%" Between Nothing
        , tableHeaderColumn "Artist" "28.0%" Between Nothing
        , tableHeaderColumn "Album" "28.0%" Last Nothing
        ]


type Pos
    = First
    | Between
    | Last


tableHeaderColumn :
    String
    -> String
    -> Pos
    -> Maybe SortBy
    -> Node
tableHeaderColumn txt width pos maybeSortBy =
    let
        cursor =
            maybeSortBy
                |> Maybe.map (always "pointer")
                |> Maybe.withDefault "default"
    in
        el
            (Tracks TableHeaderColumn)
            [ inlineStyle [ ( "cursor", cursor ), ( "width", width ) ]
            , onClick (maybeSortBy |> Maybe.map sortBy |> Maybe.withDefault TopLevel.NoOp)
            , paddingLeft
                (if pos == First then
                    scaled -2
                 else
                    scaled -4
                )
            , paddingRight
                (if pos == Last then
                    scaled -2
                 else
                    scaled -4
                )
            , paddingTop 1
            ]
            (text txt)



-- Content views, Part 2.3


defaultTableItem : Int -> Int -> IdentifiedTrack -> Html TopLevel.Msg
defaultTableItem _ _ ( identifiers, track ) =
    Html.li
        [ tableItemClasses identifiers False
        , tableItemIdentity identifiers
        ]
        [ favouriteColumn identifiers
        , otherColumn "37.5%" track.tags.title
        , otherColumn "29.0%" track.tags.artist
        , otherColumn "29.0%" track.tags.album
        ]


playlistTableItem : Maybe Int -> IdentifiedTrack -> Html TopLevel.Msg
playlistTableItem draggingOver ( identifiers, track ) =
    let
        index =
            Maybe.withDefault 0 identifiers.indexInPlaylist

        isDraggingOver =
            draggingOver
                |> Maybe.map ((==) index)
                |> Maybe.withDefault False

        nr =
            toString (index + 1)
    in
        Html.li
            (List.append
                [ tableItemClasses identifiers isDraggingOver
                , tableItemIdentity identifiers
                ]
                (DnD.itemHooks playlistDragMsg index)
            )
            [ favouriteColumn identifiers
            , otherColumn "6.00%" nr
            , otherColumn "36.5%" track.tags.title
            , otherColumn "28.0%" track.tags.artist
            , otherColumn "28.0%" track.tags.album
            ]


playlistDragMsg : DnD.Msg Int -> TopLevel.Msg
playlistDragMsg =
    TopLevel.TracksMsg << Tracks.Types.DnDMsg


tableItemClasses : Identifiers -> Bool -> Html.Attribute TopLevel.Msg
tableItemClasses identifiers draggingOver =
    Html.Attributes.classList
        [ ( "tracks__tableRow", True )
        , ( "tracks__tableRow--alt", identifiers.indexInList % 2 == 1 )
        , ( "tracks__tableRow--isMissing", identifiers.isMissing )
        , ( "tracks__tableRow--isNotMissing", not identifiers.isMissing )
        , ( "tracks__tableRow--isNowPlaying", identifiers.isNowPlaying )
        , ( "tracks__tableRow--isSelected", identifiers.isSelected )
        , ( "tracks__tableRow--draggingOver", draggingOver )
        ]


tableItemIdentity : Identifiers -> Html.Attribute TopLevel.Msg
tableItemIdentity identifiers =
    Html.Attributes.rel (toString identifiers.indexInList)


favouriteColumn : Identifiers -> Html TopLevel.Msg
favouriteColumn identifiers =
    Html.div
        [ Html.Attributes.attribute "data-favourite" (boolToAttr identifiers.isFavourite)
        , Html.Attributes.classList
            [ ( "tracks__tableFavouriteColumn", True )
            , ( "tracks__tableFavouriteColumn--isNowPlaying", identifiers.isNowPlaying )
            , ( "tracks__tableFavouriteColumn--isFavourite", identifiers.isFavourite )
            ]
        ]
        [ if identifiers.isFavourite then
            Html.text "t"
          else
            Html.text "f"
        ]


otherColumn : String -> String -> Html TopLevel.Msg
otherColumn width t =
    Html.div
        [ Html.Attributes.class "tracks__tableOtherColumns"
        , Html.Attributes.style [ ( "width", width ) ]
        ]
        [ Html.text t ]



-- Events {1}


playTrack : Decode.Decoder TopLevel.Msg
playTrack =
    Decode.map TopLevel.PlayTrack playTrackDecoder


selectTrack : Decode.Decoder TopLevel.Msg
selectTrack =
    Decode.map TopLevel.ApplyTrackSelection playTrackDecoder


playTrackDecoder : Decode.Decoder String
playTrackDecoder =
    trackRelDecoder


toggleFavourite : Decode.Decoder TopLevel.Msg
toggleFavourite =
    Decode.map (ToggleFavourite >> TopLevel.TracksMsg) toggleFavouriteDecoder


toggleFavouriteDecoder : Decode.Decoder String
toggleFavouriteDecoder =
    Decode.string
        |> Decode.at [ "target", "attributes", "data-favourite", "value" ]
        |> Decode.andThen (always trackRelDecoder)


showContextMenu : Decode.Decoder TopLevel.Msg
showContextMenu =
    Decode.map TopLevel.ShowTrackContextMenu showContextMenuDecoder


showContextMenuDecoder : Decode.Decoder ( String, Mouse.Position )
showContextMenuDecoder =
    Decode.andThen
        (\x -> Decode.andThen (Decode.succeed << (,) x) mousePositionDecoder)
        trackRelDecoder


showContextMenuOnTouch : Decode.Decoder TopLevel.Msg
showContextMenuOnTouch =
    Decode.map TopLevel.ShowTrackContextMenu showContextMenuOnTouchDecoder


showContextMenuOnTouchDecoder : Decode.Decoder ( String, Mouse.Position )
showContextMenuOnTouchDecoder =
    Decode.andThen
        (\x -> Decode.andThen (Decode.succeed << (,) x) touchPositionDecoder)
        trackRelDecoder



-- Events {2}


trackRelDecoder : Decode.Decoder String
trackRelDecoder =
    Decode.oneOf
        [ Decode.at
            [ "target", "parentNode", "attributes", "rel", "value" ]
            Decode.string
        , Decode.at
            [ "target", "attributes", "rel", "value" ]
            Decode.string
        ]


mousePositionDecoder : Decode.Decoder Mouse.Position
mousePositionDecoder =
    Decode.map2
        Mouse.Position
        (Decode.field "pageX" Decode.int)
        (Decode.field "pageY" Decode.int)


touchPositionDecoder : Decode.Decoder Mouse.Position
touchPositionDecoder =
    Decode.map2
        Mouse.Position
        (Decode.at [ "x" ] Decode.int)
        (Decode.at [ "y" ] Decode.int)


sortBy : SortBy -> TopLevel.Msg
sortBy =
    TopLevel.TracksMsg << SortBy



-- Helpers


maybeShowSortIcon : SortBy -> SortBy -> Html TopLevel.Msg -> Node
maybeShowSortIcon activeSortBy targetSortBy sortIcon =
    if targetSortBy == activeSortBy then
        el WithoutLineHeight [ alignRight, moveLeft 6, verticalCenter ] (html sortIcon)
    else
        empty


boolToAttr : Bool -> String
boolToAttr bool =
    case bool of
        True ->
            "t"

        False ->
            "f"
