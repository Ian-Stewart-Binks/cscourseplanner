import React from "react";
import PropTypes from "prop-types";

export default class InfoBox extends React.Component {

  render() {
    if (this.props.showInfoBox) {
      //TODO: move to CSS
      var gStyles = {
        cursor: "pointer",
        transition: "opacity .4s",
        opacity: this.props.showInfoBox ? 1 : 0
      };
      var rectAttrs = {
        id: this.props.nodeId + "-tooltip" + "-rect",
        x: this.props.xPos,
        y: this.props.yPos,
        rx: "4",
        ry: "4",
        fill: "white",
        stroke: "black",
        strokeWidth: "2",
        width: "60",
        height: "30"
      };

      var textAttrs = {
        id: this.props.nodeId + "-tooltip" + "-text",
        x: this.props.xPos + 60 / 2 - 18,
        y: this.props.yPos + 30 / 2 + 6
      };

      return (
        <g
          id="infoBox"
          className="tooltip-group"
          style={gStyles}
          onClick={this.props.onClick}
          onMouseEnter={this.props.onMouseEnter}
          onMouseLeave={this.props.onMouseLeave}
        >
          <rect {...rectAttrs} />
          <text {...textAttrs}>Info</text>
        </g>
      );
    } else {
      return <g />;
    }
  }
}

InfoBox.propTypes = {
  showInfoBox: PropTypes.bool,
  nodeId: PropTypes.string,
  xPos: PropTypes.number,
  yPos: PropTypes.number,
  onClick: PropTypes.func,
  onMouseEnter: PropTypes.func,
  onMouseLeave: PropTypes.func
}
