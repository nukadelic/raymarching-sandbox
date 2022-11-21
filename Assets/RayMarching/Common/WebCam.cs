
namespace Nkd
{
    using UnityEngine;
    
    public class WebCam : MonoBehaviour
    {
        public Renderer target;

        WebCamTexture webcam;

        void Start()
        {
            webcam = new WebCamTexture();

            target.material.mainTexture = webcam;

            webcam.Play();
        }
    }
}