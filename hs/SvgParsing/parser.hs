{-# LANGUAGE OverloadedStrings, FlexibleContexts, GADTs, ScopedTypeVariables #-}
module Main where

import Text.XML.HaXml
import Text.XML.HaXml.ByteStringPP
import Text.XML.HaXml.Wrappers
import Text.XML.HaXml.Types
import Text.XML.HaXml.Combinators
import Control.Monad.IO.Class  (liftIO, MonadIO)
import Text.XML.HaXml.Util
import Text.XML.HaXml.XmlContent.Parser
import qualified Data.Conduit.List as CL
import Database.Persist
import Database.Persist.Sqlite
import Control.Monad
import Control.Monad.Trans.Reader
import Text.XML.HaXml.Namespaces
import Data.Conduit
import Data.List.Split
import Data.List
import Data.Text as T (pack, unpack)
import Database.Tables
import Database.JsonParser
import SvgParsing.Generator
import SvgParsing.Builder
import SvgParsing.Types
import SvgParsing.ParserUtil
import qualified Data.Map as M

main :: IO ()
main = do graphFile <- readFile "../res/graphs/graph_regions.svg"
          let graphDoc = xmlParse "output.error" graphFile
          print "Parsing SVG file..."
          runSqlite dbStr $ do
              runMigration migrateAll
              parseLevel False (Style (0,0) "" "") (getRoot graphDoc)
              liftIO $ print "Parsing complete"
          buildSVG M.empty "../res/graphs/CSC/csc_graph.svg"
          print "SVG Built"

-- | Parses a level.
parseLevel :: MonadIO m0 =>  Bool -> Style -> Content i -> ReaderT SqlBackend m0 ()
parseLevel currentlyInRegion style content =
    if getAttribute "id" content == "layer2" ||
       (getName content == "defs")
      then return ()
      else do
           let isRegion       = getAttribute "id" content == "layer3"
               rects          = (tag "rect") content
               texts          = (tag "text") content
               paths          = (tag "path") content
               ellipses       = (tag "ellipse") content
               children       = getChildren content
               newTransform   = getAttribute "transform" content
               newStyle       = getAttribute "style" content
               newFill        = getNewStyleAttr newStyle "fill" (fill style)
               newStroke      = getNewStyleAttr newStyle "stroke" (stroke style)
               x = if null newTransform then (0,0) else parseTransform newTransform
               adjustedTransform = addTuples (transform style) x
               parentStyle = Style adjustedTransform
                                   newFill  
                                   newStroke

           parseElements (parseRect parentStyle) rects
           parseElements (parseText parentStyle) texts
           parseElements (parsePath (currentlyInRegion || isRegion) parentStyle) paths
           parseElements (parseEllipse parentStyle) ellipses
           parseChildren (currentlyInRegion || isRegion) parentStyle children

-- | Parses a list of Content.
parseChildren :: MonadIO m0 => Bool -> Style -> [Content i] -> ReaderT SqlBackend m0 ()
parseChildren _ _ [] = return ()
parseChildren currentlyInRegion style (x:xs) =
    do parseLevel currentlyInRegion style x
       parseChildren currentlyInRegion style xs

-- | Applies a parser to a list of Content.
parseElements :: MonadIO m0 => (Content i ->  ReaderT SqlBackend m0 ()) -> [Content i] -> ReaderT SqlBackend m0 ()
parseElements _ [] = return ()
parseElements f (x:xs) = do f x
                            parseElements f xs

-- | Parses a rect.
parseRect :: MonadIO m0 => Style -> Content i -> ReaderT SqlBackend m0 ()
parseRect style content = 
    insertRect (getAttribute "id" content)
                     (read $ getAttribute "width" content)
                     (read $ getAttribute "height" content)
                     ((read $ getAttribute "x" content) + fst (transform style))
                     ((read $ getAttribute "y" content) + snd (transform style))
                     style

-- | Parses a path.
parsePath :: MonadIO m0 => Bool -> Style -> Content i -> ReaderT SqlBackend m0 ()
parsePath isRegion style content =
    unless (last (getAttribute "d" content) == 'z' && not isRegion) $
        insertPath (map (addTuples (transform style)) $ parsePathD $ getAttribute "d" content)
                         style
                         isRegion

-- | Parses a text.
parseText :: MonadIO m0 => Style -> Content i -> ReaderT SqlBackend m0 ()
parseText style content = 
    insertText (getAttribute "id" content)
                     ((read $ getAttribute "x" content) + fst (transform style))
                     ((read $ getAttribute "y" content) + snd (transform style))
                     (tagTextContent content)
                     style

-- | Parses a text.
parseEllipse :: MonadIO m0 => Style -> Content i -> ReaderT SqlBackend m0 ()
parseEllipse style content = 
    insertEllipse ((read $ getAttribute "cx" content) + fst (transform style))
                        ((read $ getAttribute "cy" content) + snd (transform style))
                        (read $ getAttribute "rx" content)
                        (read $ getAttribute "ry" content)
                        (fill style)

-- | Inserts an ellipse entry into the rects table.
insertEllipse :: MonadIO m0 => Double -> Double -> Double -> Double -> String -> ReaderT SqlBackend m0 ()
insertEllipse xPos yPos rx ry stroke =
        insert_ $ Ellipses xPos
                           yPos
                           rx
                           ry
                           stroke

-- | Inserts a rect entry into the rects table.
insertRect :: MonadIO m0 => String -> Double -> Double -> Double -> Double -> Style -> ReaderT SqlBackend m0 ()
insertRect id_ width height xPos yPos style =
        insert_ $ Rects 1
                        id_
                        width
                        height
                        xPos
                        yPos
                        (fill style)
                        (stroke style)
                        (fill style == "#a14c3a")

-- | Inserts a text entry into the texts table.
insertText :: MonadIO m0 => String -> Double -> Double -> String -> Style -> ReaderT SqlBackend m0 ()
insertText id_ xPos yPos text style =
        insert_ $ Text 1
                       id_
                       xPos
                       yPos
                       text

-- | Inserts a tex entry into the texts table.
insertPath :: MonadIO m0 => [Point] -> Style -> Bool -> ReaderT SqlBackend m0 ()
insertPath d style isRegion =
        insert_ $ Paths d
                        (fill style)
                        (stroke style)
                        isRegion