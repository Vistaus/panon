
import QtQuick 2.0
import QtWebSockets 1.0
import Qt3D.Core 2.0
import Qt3D.Render 2.0
import QtQuick.Layouts 1.1

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore

import "utils.js" as Utils

Item{
    id:root

    property bool vertical: (plasmoid.formFactor == PlasmaCore.Types.Vertical)

    // Layout.minimumWidth:  plasmoid.configuration.autoHide ? animatedMinimum: -1
    Layout.preferredWidth: vertical ?-1: animatedMinimum
    Layout.preferredHeight: vertical ?  animatedMinimum:-1
    Layout.maximumWidth:plasmoid.configuration.autoHide?Layout.preferredWidth:-1
    Layout.maximumHeight:plasmoid.configuration.autoHide?Layout.preferredHeight:-1 

    // gravity property: Center(0), North (1), West (4), East (3), South (2)
    readonly property int gravity:{
        if(plasmoid.configuration.gravity>0)
            return plasmoid.configuration.gravity
        switch(plasmoid.location){
            case PlasmaCore.Types.TopEdge:
            return 2
            case PlasmaCore.Types.BottomEdge:
            return 1
            case PlasmaCore.Types.RightEdge:
            return 3
            case PlasmaCore.Types.LeftEdge:
            return 4
        }
        return 1
    }

    property int animatedMinimum:(!plasmoid.configuration.autoHide) || messageBox.length>0 ? plasmoid.configuration.preferredWidth:0 

    Layout.fillWidth: vertical? false:plasmoid.configuration.autoExtend 
    Layout.fillHeight: vertical? plasmoid.configuration.autoExtend :false

    ShaderEffect {
        id:se
        readonly property bool colorSpaceHSL:plasmoid.configuration.colorSpaceHSL
        readonly property bool colorSpaceHSLuv:plasmoid.configuration.colorSpaceHSLuv

        readonly property int hslHueFrom    :plasmoid.configuration.hslHueFrom
        readonly property int hslHueTo    :plasmoid.configuration.hslHueTo
        readonly property int hsluvHueFrom  :plasmoid.configuration.hsluvHueFrom
        readonly property int hsluvHueTo  :plasmoid.configuration.hsluvHueTo
        readonly property int hslSaturation  :plasmoid.configuration.hslSaturation
        readonly property int hslLightness   :plasmoid.configuration.hslLightness
        readonly property int hsluvSaturation:plasmoid.configuration.hsluvSaturation
        readonly property int hsluvLightness :plasmoid.configuration.hsluvLightness

        property variant tex1:texture

        property double random_seed
        property int canvas_width:root.gravity<=2?se.width:se.height
        property int canvas_height:root.gravity<=2?se.height:se.width
        property int gravity:root.gravity
        property int spectrum_width:texture.width
        property int spectrum_height:texture.height

        anchors.fill: parent
        blending: true
        fragmentShader:shaderSource.shader_source
    }

    ShaderSource{id:shaderSource}

    WebSocketServer {
        id: server
        listen: true
        onClientConnected: {
            webSocket.onTextMessageReceived.connect(function(message) {
                messageBox= message
            });
            socket=webSocket;
        }
    }

    property var socket;
    property string messageBox:""; //Message holder

    Image {id: texture;visible:false}

    property bool reduceBass:plasmoid.configuration.reduceBass
    onReduceBassChanged:sendConfig=true
    property int fps:plasmoid.configuration.fps
    onFpsChanged:sendConfig=true
    property bool sendConfig:false;

    Timer {
        interval: 1000/fps
        repeat: true
        running: true 
        onTriggered: {
            se.random_seed=Math.random()
            texture.source=messageBox  // Trigger 
        }
    }

    readonly property string startBackEnd:{
        var cmd='sh '+'"'+Utils.get_scripts_root()+'/run-client.sh'+'" '
        cmd+=server.port
        var be=['pyaudio','fifo'][plasmoid.configuration.backendIndex]
        cmd+=' --backend='+be
        if(be=='pyaudio')
            if(plasmoid.configuration.deviceIndex>=0)
                cmd+=' --device-index='+plasmoid.configuration.deviceIndex
        if(be=='fifo')
            cmd+=' --fifo-path='+plasmoid.configuration.fifoPath
        cmd+=' --fps='+plasmoid.configuration.fps
        if(plasmoid.configuration.reduceBass)
            cmd+=' --reduce-bass'
        cmd+=' --bass-resolution-level='+plasmoid.configuration.bassResolutionLevel
        return cmd
    }

    PlasmaCore.DataSource {
        engine: 'executable'
        connectedSources: [startBackEnd]
    }

    Behavior on animatedMinimum{
        enabled:plasmoid.configuration.animateAutoHiding
        NumberAnimation {
            duration: 250
            easing.type: Easing.InCubic
        }
    }
}

