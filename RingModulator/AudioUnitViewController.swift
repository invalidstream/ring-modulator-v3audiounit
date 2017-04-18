//
//  AudioUnitViewController.swift
//  RingModulator
//
//  Created by Chris Adamson on 4/18/17.
//  Provided under Creative Commons Zero license - https://creativecommons.org/publicdomain/zero/1.0/
//

import CoreAudioKit

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?
    
    @IBOutlet var frequencySlider: UISlider!

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        if audioUnit == nil {
            return
        }
        
        // Get the parameter tree and add observers for any parameters that the UI needs to keep in sync with the AudioUnit
    }
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try RingModulatorAudioUnit(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
    
    @IBAction func handleFrequencySliderValueChanged(_ sender: UISlider) {
        guard let modulatorUnit = audioUnit as? RingModulatorAudioUnit,
            let frequencyParameter = modulatorUnit.parameterTree?.parameter(withAddress: frequencyParam) else { return }
        
        frequencyParameter.setValue(sender.value, originator: nil)
        
    }
    
}
